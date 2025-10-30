import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/ad_service.dart';
import '../services/session_service.dart';
import '../widgets/guest_login_prompt.dart';
import 'quiz_screen.dart';
import '../widgets/lexiflow_toast.dart';

class DailyChallengeScreen extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final AdService adService;

  const DailyChallengeScreen({
    super.key,
    required this.wordService,
    required this.userService,
    required this.adService,
  });

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context);
    final canPlayFree = widget.userService.canPlayFreeQuiz();
    final lastQuizDate = widget.userService.getLastFreeQuizDate();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show guest prompt if user is in guest mode
    if (sessionService.isGuest) {
      return const GuestLoginPrompt();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Daily Challenge',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Trophy Icon
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Daily Challenge',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Description Card
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Quiz Info
                        Row(
                          children: [
                            Icon(
                              Icons.quiz,
                              color: Theme.of(context).colorScheme.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '10 Random Words',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                  ),
                                  Text(
                                    'From 1000+ word database',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Status
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: canPlayFree
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                canPlayFree ? Icons.check_circle : Icons.info,
                                color: canPlayFree ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  canPlayFree
                                      ? '🎉 Free play available today!'
                                      : '📺 Watch ad to play again',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: canPlayFree ? Colors.green : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (!canPlayFree && lastQuizDate != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Last played: ${_formatDate(lastQuizDate)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Start Button
                if (_isLoading)
                  CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _startQuiz,
                        icon: const Icon(Icons.play_arrow_rounded, size: 26),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            canPlayFree ? 'Start Free Quiz' : 'Watch Ad & Play',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _startQuiz() async {
    setState(() => _isLoading = true);

    try {
      final canPlayFree = widget.userService.canPlayFreeQuiz();

      // If not free, show ad
      if (!canPlayFree) {
        final adShown = await widget.adService.showRewardedAd();
        if (!adShown) {
          if (mounted) {
            _showSnackBar('Ad not ready. Please try again.', Icons.error_outline);
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Mark quiz as played (if free)
      if (canPlayFree) {
        widget.userService.markFreeQuizPlayed();
      }

      // Get 10 random words from database
      final quizWords = widget.wordService.getRandomWordsFromDatabase(10);

      if (quizWords.isEmpty) {
        if (mounted) {
          _showSnackBar('No words available for quiz', Icons.error_outline);
        }
        setState(() => _isLoading = false);
        return;
      }

      // Navigate to quiz
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuizScreen(
              wordService: widget.wordService,
              userService: widget.userService,
              quizWords: quizWords,
            ),
          ),
        ).then((_) {
          // Refresh state when returning from quiz
          if (mounted) setState(() {});
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, IconData icon) {
    if (!mounted) return;
    showLexiflowToast(
      context,
      ToastType.error,
      message,
    );
  }
}
