// lib/screens/word_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/session_service.dart';
import '../services/learned_words_service.dart';
import '../utils/design_system.dart';
import '../utils/animation_utils.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/lexiflow_toast.dart';

class WordDetailScreen extends StatefulWidget {
  final Word word;

  const WordDetailScreen({super.key, required this.word});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen>
    with SafeAnimationMixin, TickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  final LearnedWordsService _learnedWordsService = LearnedWordsService();
  bool _isSpeaking = false;
  bool _isLearned = false;
  bool _isMarkingLearned = false;

  @override
  void initState() {
    super.initState();
    initSafeController(
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    safeForward();
    _initTts();
    _checkIfWordIsLearned();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
    }
  }

  /// Check if the current word is already learned
  Future<void> _checkIfWordIsLearned() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final userId = sessionService.currentUser?.uid;

    if (userId == null) return;

    try {
      final isLearned = await _learnedWordsService.isWordLearned(
        userId,
        widget.word.word,
        word: widget.word,
      );
      if (mounted) {
        setState(() {
          _isLearned = isLearned;
        });
      }
    } catch (e) {
      // Handle error silently, default to not learned
    }
  }

  /// Toggle the learned status of the current word
  Future<void> _toggleWordLearned() async {
    final sessionService = Provider.of<SessionService>(context, listen: false);
    final userId = sessionService.currentUser?.uid;

    if (userId == null || _isMarkingLearned) return;

    setState(() {
      _isMarkingLearned = true;
    });

    try {
      bool success = false;

      if (_isLearned) {
        // Unlearn the word
        success = await _learnedWordsService.unmarkWordAsLearned(
          userId,
          widget.word.word,
          word: widget.word,
        );

        if (mounted && success) {
          setState(() {
            _isLearned = false;
            _isMarkingLearned = false;
          });

          // Show success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kelime öğrenildi listesinden çıkarıldı'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Learn the word
        success = await _learnedWordsService.markWordAsLearned(
          userId,
          widget.word,
        );

        if (mounted && success) {
          setState(() {
            _isLearned = true;
            _isMarkingLearned = false;
          });

          // Show success feedback
          showLexiflowToast(
            context,
            ToastType.success,
            'Kelime öğrenildi olarak işaretlendi! 🎉',
          );
        }
      }

      if (mounted && !success) {
        setState(() {
          _isMarkingLearned = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMarkingLearned = false;
        });

        showLexiflowToast(
          context,
          ToastType.error,
          'Bir hata oluştu. Tekrar deneyin.',
        );
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context);
    final wordService = Provider.of<WordService>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ USING APP COLOR SYSTEM - NO CUSTOM COLORS
    final backgroundColor =
        isDark ? AppDarkColors.background : AppColors.background;
    final surfaceColor = isDark ? AppDarkColors.surface : AppColors.surface;
    final primaryColor = isDark ? AppDarkColors.primary : AppColors.primary;
    final textColor =
        isDark ? AppDarkColors.textPrimary : AppColors.textPrimary;
    final secondaryTextColor =
        isDark ? AppDarkColors.textSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? null : AppGradients.primary,
          color: isDark ? backgroundColor : null,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header
              _buildModernHeader(sessionService, wordService),

              // Content with Modern Design
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      children: [
                        // Modern Word Card
                        AnimationUtils.buildSafeScaleTransition(
                          animation: safeController,
                          child: _buildModernWordCard(isDark),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Tabbed Content
                        _buildTabbedContent(isDark),

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern Header
  Widget _buildModernHeader(
    SessionService sessionService,
    WordService wordService,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          // Back Button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: AppBorderRadius.medium,
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
              ),
              iconSize: 20,
            ),
          ),
          const Spacer(),

          // Favorite Button
          if (!sessionService.isGuest && !sessionService.isAnonymous)
            StreamBuilder<Set<String>>(
              stream: wordService.favoritesKeysStream(
                sessionService.currentUser!.uid,
              ),
              builder: (context, snapshot) {
                final keys = snapshot.data ?? <String>{};
                final isFav = keys.contains(widget.word.word);
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: AppBorderRadius.medium,
                  ),
                  child: IconButton(
                    onPressed: () async {
                      await wordService.toggleFavoriteFirestore(
                        widget.word,
                        sessionService.currentUser!.uid,
                      );
                    },
                    icon: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav ? Colors.red : Colors.white,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Modern Word Card
  Widget _buildModernWordCard(bool isDark) {
    // ✅ USING APP COLOR SYSTEM
    final primaryColor = isDark ? AppDarkColors.primary : AppColors.primary;
    final surfaceColor = isDark ? AppDarkColors.surface : AppColors.surface;
    final textColor =
        isDark ? AppDarkColors.textPrimary : AppColors.textPrimary;
    final borderColor = isDark ? AppDarkColors.border : AppColors.border;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16), // ✅ Rounded corners
        border: Border.all(
          color: isDark ? borderColor : AppColors.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withOpacity(0.5)
                    : Colors.black.withOpacity(0.1),
            blurRadius: isDark ? 20 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pronunciation Button with Animation
          PulseAnimation(
            child: GestureDetector(
              onTap: () => _speak(widget.word.word),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isSpeaking
                      ? Icons.volume_up_rounded
                      : Icons.volume_up_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Word Text with Modern Typography
          Text(
            widget.word.word,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          // Word Type/Tags with Modern Design
          if (widget.word.tags.isNotEmpty)
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children:
                  widget.word.tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),

          const SizedBox(height: AppSpacing.lg),

          // Learned Button with Animation
          _buildLearnedButton(isDark),
        ],
      ),
    );
  }

  // Tabbed Content
  Widget _buildTabbedContent(bool isDark) {
    // ✅ USING APP COLOR SYSTEM
    final surfaceColor = isDark ? AppDarkColors.surface : AppColors.surface;
    final primaryColor = isDark ? AppDarkColors.primary : AppColors.primary;
    final borderColor = isDark ? AppDarkColors.border : AppColors.border;
    final textColor =
        isDark ? AppDarkColors.textPrimary : AppColors.textPrimary;
    final secondaryTextColor =
        isDark ? AppDarkColors.textSecondary : AppColors.textSecondary;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Modern Tab Bar - Dark Mode Optimized
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: isDark ? [AppShadows.medium] : null,
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: primaryColor,
              unselectedLabelColor: secondaryTextColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 13,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  text: 'Meaning',
                  icon: Icon(Icons.lightbulb_outline_rounded, size: 18),
                ),
                Tab(
                  text: 'Examples',
                  icon: Icon(Icons.format_quote_rounded, size: 18),
                ),
                Tab(
                  text: 'Details',
                  icon: Icon(Icons.info_outline_rounded, size: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Tab Content - Compact layout
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4, // Ekranın %40'ı
            child: TabBarView(
              children: [
                _buildMeaningTab(isDark),
                _buildExamplesTab(isDark),
                _buildDetailsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Meaning Tab
  Widget _buildMeaningTab(bool isDark) {
    // ✅ USING APP COLOR SYSTEM
    final primaryColor = isDark ? AppDarkColors.primary : AppColors.primary;
    final infoColor = isDark ? AppDarkColors.info : AppColors.info;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildModernInfoCard(
            icon: Icons.lightbulb_outline_rounded,
            title: 'English Meaning',
            content: widget.word.meaning,
            color: isDark ? AppDarkColors.warning : AppColors.warning,
            delay: 200,
            isDark: isDark,
          ),
          if (widget.word.tr.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _buildModernInfoCard(
              icon: Icons.translate_rounded,
              title: 'Türkçe Anlamı',
              content: widget.word.tr,
              color: infoColor,
              delay: 400,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  // Examples Tab
  Widget _buildExamplesTab(bool isDark) {
    // ✅ USING APP COLOR SYSTEM
    final successColor = isDark ? AppDarkColors.success : AppColors.success;
    final primaryColor = isDark ? AppDarkColors.primary : AppColors.primary;

    return SingleChildScrollView(
      child: Column(
        children: [
          if (widget.word.example.isNotEmpty)
            _buildModernInfoCard(
              icon: Icons.format_quote_rounded,
              title: 'Example Sentence',
              content: widget.word.example,
              color: successColor,
              delay: 200,
              isDark: isDark,
            ),
          if (widget.word.exampleSentence.isNotEmpty &&
              widget.word.exampleSentence != widget.word.example) ...[
            const SizedBox(height: AppSpacing.md),
            _buildModernInfoCard(
              icon: Icons.auto_stories_rounded,
              title: 'Additional Example',
              content: widget.word.exampleSentence,
              color: primaryColor,
              delay: 400,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  // Details Tab
  Widget _buildDetailsTab(bool isDark) {
    // ✅ USING APP COLOR SYSTEM
    final infoColor = isDark ? AppDarkColors.info : AppColors.info;
    final primaryColor = isDark ? AppDarkColors.primary : AppColors.primary;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildModernInfoCard(
            icon: Icons.info_outline_rounded,
            title: 'Word Information',
            content:
                'Type: ${widget.word.tags.isNotEmpty ? widget.word.tags.join(', ') : 'General'}',
            color: infoColor,
            delay: 200,
            isDark: isDark,
          ),
          if (widget.word.isCustom) ...[
            const SizedBox(height: AppSpacing.md),
            _buildModernInfoCard(
              icon: Icons.edit_rounded,
              title: 'Custom Word',
              content: 'This is a custom word added by you.',
              color: primaryColor,
              delay: 400,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }

  // Modern Info Card
  Widget _buildModernInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    required int delay,
    required bool isDark,
  }) {
    // ✅ USING APP COLOR SYSTEM
    final backgroundColor = isDark ? AppDarkColors.surface : AppColors.surface;
    final textColor =
        isDark ? AppDarkColors.textPrimary : AppColors.textPrimary;
    final borderColor = isDark ? AppDarkColors.border : AppColors.borderLight;

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final safeValue = AnimationUtils.getSafeOpacity(value);
        return Transform.translate(
          offset: AnimationUtils.getSafeTranslation(safeValue, 20),
          child: Opacity(opacity: safeValue, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16), // ✅ Rounded corners
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color:
                  isDark
                      ? Colors.black.withOpacity(0.4)
                      : Colors.black.withOpacity(0.08),
              blurRadius: isDark ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                color: textColor,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the learned button with animation
  Widget _buildLearnedButton(bool isDark) {
    final sessionService = Provider.of<SessionService>(context);

    // Don't show for guests or anonymous users
    if (sessionService.isGuest || sessionService.isAnonymous) {
      return const SizedBox.shrink();
    }

    final primaryColor = isDark ? AppDarkColors.primary : AppColors.primary;
    final successColor = isDark ? AppDarkColors.success : AppColors.success;
    final textColor =
        isDark ? AppDarkColors.textPrimary : AppColors.textPrimary;
    final surfaceColor = isDark ? AppDarkColors.surface : AppColors.surface;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child:
          _isLearned
              ? GestureDetector(
                key: const ValueKey('learned'),
                onTap: _isMarkingLearned ? null : _toggleWordLearned,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: successColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isMarkingLearned)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              successColor,
                            ),
                          ),
                        )
                      else
                        Icon(Icons.check_circle, color: successColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isMarkingLearned ? 'İşleniyor...' : 'Öğrenildi',
                        style: TextStyle(
                          color: successColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : GestureDetector(
                key: const ValueKey('not_learned'),
                onTap: _isMarkingLearned ? null : _toggleWordLearned,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _isMarkingLearned
                            ? primaryColor.withOpacity(0.05)
                            : primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isMarkingLearned)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryColor,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.check_circle_outline,
                          color: primaryColor,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        _isMarkingLearned
                            ? 'İşaretleniyor...'
                            : 'Bu kelimeyi öğrendim',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
