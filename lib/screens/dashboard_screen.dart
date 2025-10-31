import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
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
import '../widgets/loading_widgets.dart';
import '../widgets/offline_indicator.dart';
import '../services/notification_service.dart';
import 'word_detail_screen.dart';
import 'statistics_screen.dart';
import 'leaderboard_screen.dart';
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

  List<Word> _dailyWords = [];
  bool _isLoading = true;
  bool _isFirstLoaded = false; // latch for first load shimmer
  final bool _isExtended = false;
  List<String> _allWordIds = [];

  // Daily word system state
  Map<String, dynamic>? _dailyWordsData;
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;

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
    
    _loadDailyWords();
    _scheduleNotifications();
    _startCountdownTimer();
  }

  void _scheduleNotifications() async {
    try {
      await _notificationService.applySchedulesFromPrefs();
    } catch (e) {
      debugPrint('Notification scheduling failed: $e');
    }
  }

  Future<void> _loadDailyWords() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _sessionService.currentUser;
      
      if (user == null) {
        final words = await _wordService.getRandomWords(5);
        setState(() {
          _dailyWords = words;
          _isLoading = false;
          _isFirstLoaded = true; // mark as loaded
        });
        debugPrint('I/flutter: [HOME] firstLoad->$_isFirstLoaded, showingShimmer=${!_isFirstLoaded}');
        return;
      }

      // AdService.initialize() kaldırıldı - gereksiz tekrar çağrı

      // Use correct method name and handle the response properly
      final dailyWordsData = await _dailyWordService.getTodaysWords(user.uid);
      final dailyWordIds = List<String>.from(dailyWordsData['dailyWords'] ?? []);
      final extraWordIds = List<String>.from(dailyWordsData['extraWords'] ?? []);
      
      // Combine daily and extra word IDs
      final allWordIds = [...dailyWordIds, ...extraWordIds];
      
      // Get actual Word objects from IDs
      final words = await _dailyWordService.getWordsByIds(allWordIds);

      setState(() {
        _dailyWords = words;
        _allWordIds = allWordIds;
        _dailyWordsData = dailyWordsData;
        _isLoading = false;
        _isFirstLoaded = true; // mark as loaded
      });
      debugPrint('I/flutter: [HOME] firstLoad->$_isFirstLoaded, showingShimmer=${!_isFirstLoaded}');
    } catch (e) {
      debugPrint('Error loading daily words: $e');
      
      try {
        final words = await _wordService.getRandomWords(5);
        setState(() {
          _dailyWords = words;
          _isLoading = false;
          _isFirstLoaded = true; // mark as loaded even on fallback
        });
        debugPrint('I/flutter: [HOME] firstLoad->$_isFirstLoaded, showingShimmer=${!_isFirstLoaded}');
      } catch (fallbackError) {
        debugPrint('Fallback error: $fallbackError');
        setState(() {
          _isLoading = false;
          _isFirstLoaded = true; // mark as loaded even on error
        });
        debugPrint('I/flutter: [HOME] firstLoad->$_isFirstLoaded, showingShimmer=${!_isFirstLoaded}');
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
    });
  }

  void _updateTimeUntilReset() {
    if (mounted) {
      setState(() {
        _timeUntilReset = _dailyWordService.getTimeUntilReset();
      });
    }
  }

  void _showSnackBar(String message, IconData icon, {Color? color}) {
    if (!mounted) return;
    ToastType toastType = ToastType.info;
    if (color == Colors.green) {
      toastType = ToastType.success;
    } else if (icon == Icons.error_outline) {
      toastType = ToastType.error;
    }
    
    showLexiflowToast(
      context,
      toastType,
      message,
    );
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

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin gereksinimi
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // shimmer sadece ilk yüklemede göster
    if (_isLoading && !_isFirstLoaded) {
      return Column(
        children: [
          // Offline durum göstergesi
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: OfflineIndicator(compact: true),
          ),
          // Modern Header Skeleton
          const DashboardHeaderSkeleton(),
          // Content with shimmer loading
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: List.generate(
                  5,
                  (index) => ShimmerLoading(
                    child: WordCardSkeleton(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDailyWords,
      child: CustomScrollView(
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
                  Row(
                    children: [
                      // Statistics Button
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(0.9),
                          borderRadius: AppBorderRadius.medium,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.bar_chart_rounded,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 24,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StatisticsScreen(),
                              ),
                            );
                          },
                          tooltip: 'İstatistikler',
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Streak Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surface.withOpacity(0.9),
                          borderRadius: AppBorderRadius.large,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: AppSpacing.sm),
                            Consumer<SessionService>(
                              builder: (context, sessionService, child) {
                                final streak = sessionService.currentStreak;
                                return Text(
                                  '$streak',
                                  style: AppTextStyles.title3.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Spacer before greeting
              const SizedBox(height: AppSpacing.lg),

              // Greeting Section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good ${_getTimeOfDay()}!',
                          style: AppTextStyles.headline3.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Ready to learn?',
                          style: AppTextStyles.body1.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LeaderboardScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppBorderRadius.large,
                        boxShadow: [AppShadows.medium],
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: AppColors.surface,
                        size: 40,
                      ),
                    ),
                  ),
                ],
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
                          final learnedCount = profileProvider.learnedCount ?? 0;
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
    final colors = isDark
        ? AppDarkColors.successGradient
        : AppColors.successGradient; // turkuaz-yeşil degrade

    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          try { HapticFeedback.lightImpact(); } catch (_) {}
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
                    Icon(AppIcons.sparkles,
                        color: theme.colorScheme.primary, size: 24),
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
                    Icon(AppIcons.zap,
                        size: 18,
                        color: theme.colorScheme.secondary.withOpacity(0.9)),
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
                    Icon(AppIcons.clock,
                        size: 18,
                        color: theme.colorScheme.secondary.withOpacity(0.9)),
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
                    Icon(AppIcons.brain,
                        size: 18,
                        color: theme.colorScheme.secondary.withOpacity(0.9)),
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
                          try { HapticFeedback.mediumImpact(); } catch (_) {}
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DailyChallengeScreen(
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
                  builder: (_) => DailyChallengeScreen(
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
          )
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
    final hours = _timeUntilReset.inHours;
    final minutes = _timeUntilReset.inMinutes % 60;
    final seconds = _timeUntilReset.inSeconds % 60;

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
  }
}
