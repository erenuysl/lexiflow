import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/ad_service.dart';
import '../services/session_service.dart';
import '../services/daily_word_service.dart';
import '../services/statistics_service.dart';
import '../utils/design_system.dart';
import '../utils/app_icons.dart';
import 'package:flutter/services.dart';
import '../utils/feature_flags.dart';
import '../widgets/offline_indicator.dart';
import '../services/notification_service.dart';
import 'word_detail_screen.dart';
import 'statistics_screen.dart';
// TODO: Re-enable Leaderboard UI if needed later
// import 'leaderboard_screen.dart';
import '../widgets/lexiflow_toast.dart';
import 'daily_challenge_screen.dart';
import '../providers/profile_stats_provider.dart';

class DashboardScreen extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final AdService adService;

  const DashboardScreen({
    super.key,
    required this.wordService,
    required this.userService,
    required this.adService,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// removed old pinned header delegate in favor of FAB coach UI

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final DailyWordService _dailyWordService = DailyWordService();
  final StatisticsService _statisticsService = StatisticsService();
  final NotificationService _notificationService = NotificationService();

  // Service references from widget
  late final WordService _wordService;
  late final UserService _userService;
  late final AdService _adService;
  late final SessionService _sessionService;

  // Cache shared across potential re-creations of DashboardScreen
  static List<Word>? _cachedDailyWords;
  static DateTime? _cacheTimestamp;
  static bool _initialLoadDone = false;

  List<Word> _dailyWords = [];
  // Start in loading state ONLY if we don't have cached data yet
  bool _isLoading = !_initialLoadDone;
  bool _isFirstLoaded = false; // legacy latch; superseded by _initialLoadDone
  final bool _isExtended = false;
  List<String> _allWordIds = [];

  // Daily word system state
  Map<String, dynamic>? _dailyWordsData;
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero; // retained for legacy but not used for rebuilds
  DateTime? _lastBuildLog;
  bool _midnightTriggered = false;
  static String? _cachedDate; // UTC date string for cached words (YYYY-MM-DD)
  // Cache initial home load to avoid recreating futures on rebuilds
  late Future<void> _homeFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Initialize service references from widget
    _wordService = widget.wordService;
    _userService = widget.userService;
    _adService = widget.adService;
    _sessionService = Provider.of<SessionService>(context, listen: false);

    // Eğer cache varsa anında göster ve arka planda sessizce yenile
    if (_cachedDailyWords != null && _cachedDailyWords!.isNotEmpty) {
      _dailyWords = _cachedDailyWords!;
      _isLoading = false;
      _isFirstLoaded = true;
      _initialLoadDone = true;
      // Sessiz arka plan yenileme (spinner yok)
      _homeFuture = _loadDailyWords(silent: true);
    } else {
      // Verileri arka planda yükle ve geleceği (future) cache'le
      // Böylece yeniden oluşturmalarda yeni future üretilmez
      _homeFuture = _loadDailyWords();
    }
    Future.microtask(_scheduleNotifications);
    _startCountdownTimer();
  }

  void _scheduleNotifications() async {
    try {
      final userId = _sessionService.currentUser?.uid;
      await _notificationService.applySchedulesFromPrefs(userId: userId);
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
  }

  Future<void> _loadDailyWords({bool silent = false}) async {
    if (!mounted) return;
    // Yalnızca ilk yüklemede spinner göster; cache varsa sessizce yenile
    if (!silent) {
      setState(() {
        _isLoading = !_initialLoadDone;
      });
    }

    try {
      final user = _sessionService.currentUser;

      if (user == null) {
        final words = await _wordService.getRandomWords(5);
        setState(() {
          _dailyWords = words;
          if (!silent) _isLoading = false;
          _isFirstLoaded = true; // mark as loaded
          _initialLoadDone = true;
        });
        _cachedDailyWords = words;
        _cacheTimestamp = DateTime.now();
        _cachedDate = _todayDateUtcString();
        return;
      }

      // AdService.initialize() kaldırıldı - gereksiz tekrar çağrı

      // Use the requested format for daily words loading
      final dailyWordsData = await _dailyWordService.getTodaysWords(user.uid);
      _dailyWordsData = dailyWordsData;
      final dailyWordIds = List<String>.from(
        dailyWordsData['dailyWords'] ?? [],
      );

      // Get actual Word objects from IDs
      var words = await _dailyWordService.getWordsByIds(dailyWordIds);
      if (words.isEmpty) {
        debugPrint('Daily words empty → fallback to general category');
        final fallback = await _wordService.getCategoryWords('general') ?? [];
        words = fallback.take(10).toList();
      }

      setState(() {
        _dailyWords = words;
        if (!silent) _isLoading = false;
        _isFirstLoaded = true; // mark as loaded
        _initialLoadDone = true;
      });
      _cachedDailyWords = words;
      _cacheTimestamp = DateTime.now();
      _cachedDate = (dailyWordsData['date'] ?? _todayDateUtcString()).toString();
    } catch (e) {
      debugPrint('Error loading daily words: $e');

      try {
        final words = await _wordService.getRandomWords(5);
        // ek fallback: eğer random words da boşsa general kategorisinden yükle
        if (words.isEmpty) {
          debugPrint('Random words also empty, trying general category');
          final generalWords = await _wordService.getCategoryWords('general');
          final fallbackWords = generalWords.take(10).toList();
          setState(() {
            _dailyWords = fallbackWords;
            if (!silent) _isLoading = false;
            _isFirstLoaded = true;
            _initialLoadDone = true;
          });
          _cachedDailyWords = fallbackWords;
          _cacheTimestamp = DateTime.now();
          _cachedDate = _todayDateUtcString();
          // shimmer kaldırıldı; yalnızca sessiz fallback
        } else {
          setState(() {
            _dailyWords = words;
            if (!silent) _isLoading = false;
            _isFirstLoaded = true; // mark as loaded even on fallback
            _initialLoadDone = true;
          });
          _cachedDailyWords = words;
          _cacheTimestamp = DateTime.now();
          _cachedDate = _todayDateUtcString();
        }
      } catch (fallbackError) {
        debugPrint('Fallback error: $fallbackError');
        setState(() {
          if (!silent) _isLoading = false;
          _isFirstLoaded = true; // mark as loaded even on error
          _initialLoadDone = true;
        });
      }
    }
  }

  Future<void> _loadMoreWords() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final userId = sessionService.currentUser?.uid;

    if (userId == null) {
      _showSnackBar('Please sign in to unlock more words', Icons.error_outline);
      return;
    }

    try {
      final success = await _dailyWordService.addExtraWordsAfterAd(userId);

      if (success) {
        await _loadDailyWords();

        final prevLevel = sessionService.level;
        await sessionService.addXp(10);
        final leveledUpResult = sessionService.level > prevLevel;

        try {
          await _statisticsService.recordActivity(
            userId: userId,
            xpEarned: 10,
            learnedWordsCount: 5, // 5 new words unlocked
            quizzesCompleted: 0,
          );
          debugPrint('✅ Activity recorded: 10 XP for unlocking words');
        } catch (e) {
          debugPrint('⚠️ Failed to record activity: $e');
        }

        if (leveledUpResult) {
          _showLevelUpDialog(sessionService.level);
        } else {
          _showSnackBar(
            '🎉 +5 new words unlocked! +10 XP',
            Icons.celebration,
            color: Colors.green,
          );
        }
      } else {
        _showSnackBar('Ad not ready. Please try again.', Icons.error_outline);
      }
    } catch (e) {
      debugPrint('❌ Error loading more words: $e');
      _showSnackBar('Failed to load more words', Icons.error_outline);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _dailyWordService.dispose();
    super.dispose();
  }

  Future<void> _maybeScheduleDailyReminder() async {
    if (!FeatureFlags.dailyCoachEnabled) return;
    try {
      final svc = NotificationService();
      await svc.init();
      await svc.requestPermission();
      final due = widget.wordService.getDueReviewCount();
      await svc.scheduleDaily(
        id: NotificationService.idReview,
        title: 'Gözden Geçirme Zamanı',
        body: 'Bekleyen $due kelimen var',
        time: const TimeOfDay(hour: 20, minute: 0),
        payload: '/favorites',
      );
    } catch (_) {
      // Best-effort: ignore notification errors
    }
  }

  void _startCountdownTimer() {
    _updateTimeUntilReset();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTimeUntilReset();
      // When the reset time hits 00:00 UTC, refresh daily words silently
      final remaining = _dailyWordService.getTimeUntilReset();
      if (remaining.inSeconds <= 0 && !_midnightTriggered) {
        _midnightTriggered = true;
        // Clear cache and fetch new set silently
        Future.microtask(() async {
          await _loadDailyWords(silent: true);
          // Update date cache after refresh
          _cachedDate = _todayDateUtcString();
        });
      }
    });
  }

  void _updateTimeUntilReset() {
    // Ekranı her saniye yeniden çizmemek için setState kaldırıldı.
    // Geri sayım artık StreamBuilder ile izole şekilde güncelleniyor.
    _timeUntilReset = _dailyWordService.getTimeUntilReset();
  }

  String _todayDateUtcString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message, IconData icon, {Color? color}) {
    if (!mounted) return;
    ToastType toastType = ToastType.info;
    if (color == Colors.green) {
      toastType = ToastType.success;
    } else if (icon == Icons.error_outline) {
      toastType = ToastType.error;
    }

    showLexiflowToast(context, toastType, message);
  }

  void _showLevelUpDialog(int newLevel) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tebrikler!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Seviye $newLevel\'e ulaştın!',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '🎉 Harika gidiyorsun! 🎉',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Devam Et',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın!';
    if (hour < 17) return 'İyi Öğleden Sonralar!';
    if (hour < 21) return 'İyi Akşamlar!';
    return 'İyi Geceler!';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin gereksinimi
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Build loglarını azaltmak için basit throttle
    final now = DateTime.now();
    if (kDebugMode && (_lastBuildLog == null ||
        now.difference(_lastBuildLog!) > const Duration(seconds: 3))) {
      debugPrint(
        '[DashboardScreen] build -> isLoading=$_isLoading dailyWords=${_dailyWords.length}',
      );
      _lastBuildLog = now;
    }

    // Revisited Home tab: show cached content immediately and refresh in background
    if (_initialLoadDone && !_isLoading) {
      final shouldRefreshSilently =
          _cacheTimestamp == null ||
          now.difference(_cacheTimestamp!) > const Duration(seconds: 10);
      if (shouldRefreshSilently) {
        Future.microtask(() => _loadDailyWords(silent: true));
      }
    }
    
    // Ana içerik: veriler hazırsa göster, değilse boş
    final Widget content = RefreshIndicator(
      onRefresh: _loadDailyWords,
      child: CustomScrollView(
        // Preserve scroll position across tab switches
        key: const PageStorageKey<String>('dashboard_scroll'),
        slivers: [
          // Modern Header with Gradient
          SliverToBoxAdapter(child: _buildModernHeader(isDark)),

          // Modern Word Cards Grid
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index < _dailyWords.length) {
                  return _buildModernWordCard(
                    _dailyWords[index],
                    index,
                    isDark,
                  );
                } else if (!_isExtended) {
                  return _buildModernMoreWordsCard(isDark);
                }
                return const SizedBox.shrink();
              }, childCount: _dailyWords.length + (!_isExtended ? 1 : 0)),
            ),
          ),
        ],
      ),
    );

    const loadingState = Center(child: CircularProgressIndicator.adaptive());

    // Shimmer kaldırıldı; bunun yerine yumuşak fade-in geçişi
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        ),
        // Yalnızca ilk açılışta loading göster; cache varsa anında içerik
        child: (!_initialLoadDone && _isLoading) ? loadingState : content,
      ),
    );
  }

  // Modern Header
  Widget _buildModernHeader(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDark
                  ? [
                    const Color(0xFF1E293B), // Dark mode ilk renk
                    const Color(0xFF334155), // Dark mode ikinci renk
                  ]
                  : [
                    const Color(0xFFF8FAFC), // Light mode ilk renk
                    const Color(0xFFE2E8F0), // Light mode ikinci renk
                  ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Title with Streak
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LexiFlow',
                    style: AppTextStyles.title1.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final colorScheme = Theme.of(context).colorScheme;

                      BoxDecoration decoration() => BoxDecoration(
                        color: colorScheme.surface.withOpacity(0.9),
                        borderRadius: AppBorderRadius.medium,
                        border: Border.all(
                          color: colorScheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      );

                      Widget decoratedIconButton({
                        required Icon icon,
                        required VoidCallback onPressed,
                        required String tooltip,
                      }) {
                        return Container(
                          decoration: decoration(),
                          child: IconButton(
                            icon: icon,
                            onPressed: onPressed,
                            tooltip: tooltip,
                          ),
                        );
                      }

                      return Row(
                        children: [
                          // Streak Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: decoration().copyWith(
                              borderRadius: AppBorderRadius.large,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🔥',
                                  style: TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Consumer<ProfileStatsProvider>(
                                  builder: (
                                    context,
                                    profileStatsProvider,
                                    child,
                                  ) {
                                    final streak =
                                        profileStatsProvider.currentStreak;
                                    return Text(
                                      '$streak',
                                      style: AppTextStyles.title3.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // Analytics Button
                          decoratedIconButton(
                            icon: Icon(
                              Icons.bar_chart_rounded,
                              color: colorScheme.onSurface,
                              size: 24,
                            ),
                            tooltip: 'İstatistikler',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const StatisticsScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // TODO: Re-enable Leaderboard UI if needed later
                          // Leaderboard Button (hidden)
                          // decoratedIconButton(
                          //   icon: const Icon(
                          //     Icons.emoji_events_rounded,
                          //     color: Color(0xFFFFC107),
                          //     size: 26,
                          //   ),
                          //   tooltip: 'Liderlik Tablosu',
                          //   onPressed: () {
                          //     Navigator.push(
                          //       context,
                          //       MaterialPageRoute(
                          //         builder:
                          //             (context) => const LeaderboardScreen(),
                          //       ),
                          //     );
                          //   },
                          // ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Greeting Section
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreetingMessage(),
                      style: AppTextStyles.headline3.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hazır mısın öğrenmeye?',
                      style: AppTextStyles.body1.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Countdown Timer (small, subtle)
              _buildCountdownTimer(),
              const SizedBox(height: AppSpacing.md),

              // Modern Stats Card
              ModernCard(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surface.withOpacity(0.9),
                shadows: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
                showBorder: true,
                child: Row(
                  children: [
                    Expanded(
                      child: Consumer<ProfileStatsProvider>(
                        builder: (context, profileProvider, _) {
                          final learnedCount =
                              profileProvider.learnedCount ?? 0;
                          return _buildModernStatItem(
                            Icons.school,
                            '$learnedCount',
                            'Öğrenilen Kelime',
                          );
                        },
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    Expanded(
                      child: Consumer<SessionService>(
                        builder: (context, sessionService, _) {
                          final favCount = sessionService.favoritesCount;
                          return _buildModernStatItem(
                            Icons.favorite_rounded,
                            '$favCount',
                            'Favorites',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoachFab(BuildContext context) {
    final due = widget.wordService.getDueReviewCount();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colors =
        isDark
            ? AppDarkColors.successGradient
            : AppColors.successGradient; // turkuaz-yeşil degrade

    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          try {
            HapticFeedback.lightImpact();
          } catch (_) {}
          _showCoachSheet(context, due);
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            shape: BoxShape.circle,
          ),
          width: 56,
          height: 56,
          child: const Center(
            child: Icon(AppIcons.sparkles, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }

  Future<void> _showCoachSheet(BuildContext context, int due) async {
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      AppIcons.sparkles,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Günlük Koç',
                      style: AppTextStyles.title2.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  due > 0
                      ? 'Bugün $due kart hazır. Kısa bir tekrar öneriyoruz.'
                      : 'Yeni kelimeler seni bekliyor. Başlayalım mı?',
                  style: AppTextStyles.body2.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // What it does (explanatory bullets)
                Row(
                  children: [
                    Icon(
                      AppIcons.zap,
                      size: 18,
                      color: theme.colorScheme.secondary.withOpacity(0.9),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Doğru aralıklarla tekrar planlar (FSRS).',
                        style: AppTextStyles.body3.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      AppIcons.clock,
                      size: 18,
                      color: theme.colorScheme.secondary.withOpacity(0.9),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Günlük hedefini tek akışta tamamlarsın.',
                        style: AppTextStyles.body3.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      AppIcons.brain,
                      size: 18,
                      color: theme.colorScheme.secondary.withOpacity(0.9),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Cevap kalitesine göre kişiselleştirir (Zordu/İyiydi/Çok kolay).',
                        style: AppTextStyles.body3.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          try {
                            HapticFeedback.mediumImpact();
                          } catch (_) {}
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => DailyChallengeScreen(
                                    wordService: widget.wordService,
                                    userService: widget.userService,
                                    adService: widget.adService,
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(AppIcons.play),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Devam Et',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Kapat'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyCoachCard(BuildContext context) {
    final dueCount = widget.wordService.getDueReviewCount();
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: AppBorderRadius.large,
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Günlük Koç',
                  style: AppTextStyles.title2.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dueCount > 0
                      ? 'Hazır kartlar: $dueCount • Devam edelim mi?'
                      : 'Yeni kelimeler seni bekliyor',
                  style: AppTextStyles.body2.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          ElevatedButton(
            onPressed: () {
              // Navigate to Daily Challenge as the single flow
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => DailyChallengeScreen(
                        wordService: widget.wordService,
                        userService: widget.userService,
                        adService: widget.adService,
                      ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Devam Et',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modern Stat Item
  Widget _buildModernStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 24),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          style: AppTextStyles.title2.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // Modern Word Card
  Widget _buildModernWordCard(Word word, int index, bool isDark) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: ModernCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        backgroundColor: Theme.of(context).colorScheme.surface,
        shadows: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        showBorder: true,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WordDetailScreen(word: word),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and favorite button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: AppBorderRadius.medium,
                  ),
                  child: Icon(
                    Icons.translate_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    word.word,
                    style: AppTextStyles.title1.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Modern Favorite Button
                Consumer<SessionService>(
                  builder: (context, sessionService, _) {
                    final isGuest =
                        sessionService.isGuest || sessionService.isAnonymous;
                    if (isGuest) return const SizedBox.shrink();

                    return StreamBuilder<Set<String>>(
                      stream: widget.wordService.favoritesKeysStream(
                        sessionService.currentUser!.uid,
                      ),
                      builder: (context, snapshot) {
                        final keys = snapshot.data ?? <String>{};
                        final isFav = keys.contains(word.word);
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isFav
                                    ? AppColors.error.withOpacity(0.1)
                                    : AppColors.surfaceVariant,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color:
                                  isFav
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed:
                                () =>
                                    widget.wordService.toggleFavoriteFirestore(
                                      word,
                                      sessionService.currentUser!.uid,
                                    ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Meaning
            Text(
              word.meaning,
              style: AppTextStyles.body1.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            ),

            // Turkish Translation
            if (word.tr.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: AppBorderRadius.medium,
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withOpacity(0.4),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇹🇷', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      word.tr,
                      style: AppTextStyles.body2.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Example Sentence
            if (word.exampleSentence.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppBorderRadius.medium,
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.shadow.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 20,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.7),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        word.exampleSentence,
                        style: AppTextStyles.body2.copyWith(
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Modern More Words Card
  Widget _buildModernMoreWordsCard(bool isDark) {
    return ModernCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      backgroundColor: Theme.of(context).colorScheme.surface,
      shadows: [
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withOpacity(0.15),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
      showBorder: true,
      onTap: _loadMoreWords,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '+5 More Words',
            style: AppTextStyles.title1.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Watch a quick ad to unlock',
            style: AppTextStyles.body2.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  // Countdown Timer Widget (small and subtle)
  Widget _buildCountdownTimer() {
    // Her saniye yalnızca sayaç satırını güncelleyen hafif bir akış.
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final duration = _dailyWordService.getTimeUntilReset();
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        final seconds = duration.inSeconds % 60;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
            borderRadius: AppBorderRadius.medium,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Yenilenme: ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: AppTextStyles.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
