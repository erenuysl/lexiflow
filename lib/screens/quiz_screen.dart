import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/session_service.dart';
import '../services/srs_service.dart';
import '../services/analytics_service.dart';
import '../services/remote_config_service.dart';
import '../services/leaderboard_service.dart';
import '../services/weekly_xp_service.dart';
import '../utils/feature_flags.dart';
import '../utils/logger.dart';
import 'quiz_results_screen.dart';
import 'dart:async';
import '../services/statistics_service.dart';
import 'package:flutter/services.dart';
import '../widgets/guest_login_prompt.dart';
import '../widgets/lexiflow_toast.dart';
import '../di/locator.dart';

class QuizScreen extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final List<Word>? quizWords;
  final String? quizType;

  const QuizScreen({
    super.key,
    required this.wordService,
    required this.userService,
    this.quizWords,
    this.quizType,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Word> _quizWords = [];
  int _currentIndex = 0;
  int _score = 0;
  List<Word> _options = [];
  Word? _correctWord;
  Word? _selectedWord;
  bool _isAnswered = false;
  bool _isInitializing = true;
  bool _hasError = false;
  String _errorMessage = '';
  late ConfettiController _confettiController;

  final Map<Word, bool> _quizResults = {};
  final Map<Word, int> _responseTimesMs = {};
  final Map<Word, int> _qualities = {};
  DateTime? _questionShownAt;
  final StatisticsService _statistics = StatisticsService();
  
  // kalite sorusu her 4 doğru cevapta bir sorulur
  int _correctAnswerCount = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _initQuiz();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _initQuiz() {
    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      if (widget.quizWords != null && widget.quizWords!.isNotEmpty) {
        _quizWords = List.from(widget.quizWords!);
      } else {
        final favorites = widget.wordService.getFavoriteWords();
        
        if (favorites.length >= 4) {
          _quizWords = widget.wordService.getRandomFavorites(
            min(10, favorites.length),
          );
        }
      }

      if (_quizWords.isNotEmpty) {
        _quizWords.shuffle();
        _generateQuestion();
        
        final quizType = widget.quizType ?? (widget.quizWords != null ? 'custom' : 'favorites');
        AnalyticsService.logQuizStarted(
          quizType: quizType,
          wordCount: _quizWords.length,
        );
        Logger.i('Quiz started: $quizType with ${_quizWords.length} words', 'QuizScreen');
        
        setState(() {
          _isInitializing = false;
        });
      } else {
        setState(() {
          _isInitializing = false;
          _hasError = true;
          _errorMessage = 'No words available for quiz';
        });
      }
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _hasError = true;
        _errorMessage = 'Failed to initialize quiz: $e';
      });
    }
  }

  void _generateQuestion() {
    if (_currentIndex >= _quizWords.length) {
      return;
    }

    try {
      _correctWord = _quizWords[_currentIndex];

      final allWords = widget.wordService.getAllWords();
      final wrongWords = allWords.where((w) => w.word != _correctWord!.word).toList();

      if (wrongWords.length < 3) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Not enough words in database for quiz';
        });
        return;
      }

      wrongWords.shuffle();
      final distractors = wrongWords.take(3).toList();
      _options = [_correctWord!, ...distractors];
      _options.shuffle();

      _questionShownAt = DateTime.now();
      setState(() {});

      try {
        final session = locator<SessionService>();
        final uid = session.currentUser?.uid;
        if (uid != null && _correctWord != null) {
          _statistics.logReviewStart(userId: uid, wordId: _correctWord!.word);
        }
      } catch (e) {
        // sessiz hata, devam et
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to generate question: $e';
      });
    }
  }

  Future<void> _checkAnswer(Word selectedWord) async {
    if (_isAnswered) return;

    setState(() {
      _selectedWord = selectedWord;
      _isAnswered = true;
    });

    final isCorrect = selectedWord.word == _correctWord!.word;
    final now = DateTime.now();
    final rtMs = _questionShownAt != null
        ? now.difference(_questionShownAt!).inMilliseconds
        : 0;

    try {
      if (isCorrect) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (_) {}

    _quizResults[_correctWord!] = isCorrect;
    _responseTimesMs[_correctWord!] = rtMs;

    if (isCorrect) {
      _score++;
      _correctAnswerCount++;
      _showFeedback(true);
      _confettiController.play();
    } else {
      _showFeedback(false);
    }

    if (isCorrect) {
      if (FeatureFlags.fsrsQualityPromptEnabled) {
        final promptRatio = RemoteConfigService.getFsrsPromptRatio();
        
        if (_correctAnswerCount % promptRatio == 0) {
          final chosen = await _showQualityPrompt();
          _qualities[_correctWord!] = chosen ?? 2;
          Logger.d('Quality prompt shown (every ${promptRatio}th correct): $_correctAnswerCount', 'QuizScreen');
        } else {
          _qualities[_correctWord!] = 2;
          final nextPrompt = ((_correctAnswerCount ~/ promptRatio) + 1) * promptRatio;
          Logger.d('Quality prompt skipped: $_correctAnswerCount (ask at $nextPrompt)', 'QuizScreen');
        }
      } else {
        _qualities[_correctWord!] = 2;
      }
    } else {
      _qualities[_correctWord!] = 0;
    }

    try {
      final session = locator<SessionService>();
      final uid = session.currentUser?.uid;
      final q = _qualities[_correctWord!] ?? (isCorrect ? 2 : 0);
      
      if (uid != null && _correctWord != null) {
        await _statistics.logReviewAnswered(
          userId: uid,
          wordId: _correctWord!.word,
          rating: q,
          reviewTime: Duration(milliseconds: rtMs),
        );
      }
    } catch (e) {
      // sessiz hata, devam et
    }

    await Future.delayed(const Duration(milliseconds: 1500));

    if (_currentIndex >= _quizWords.length - 1) {
      _finishQuiz();
    } else {
      setState(() {
        _currentIndex++;
        _selectedWord = null;
        _isAnswered = false;
      });
      _generateQuestion();
    }
  }

  void _finishQuiz() async {
    final earnedXp = _score * 10;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => QuizResultsScreen(
          score: _score,
          totalQuestions: _quizWords.length,
          earnedXp: earnedXp,
          leveledUp: false, // seviye sistemi henüz yok
          currentLevel: 1, // seviye sistemi henüz yok
          quizType: widget.quizType,
          onPlayAgain: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => QuizScreen(
                  wordService: widget.wordService,
                  userService: widget.userService,
                  quizWords: widget.quizWords,
                  quizType: widget.quizType,
                ),
              ),
            );
          },
          onBackToFavorites: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    try {
      final sessionService = locator<SessionService>();
      final uid = sessionService.currentUser?.uid;

      if (uid != null) {
        for (final entry in _quizResults.entries) {
          final word = entry.key;
          final isCorrect = entry.value;
          
          if (isCorrect) {
            try {
              await widget.wordService.addToLearnedWords(word, uid);
            } catch (e) {
              // sessiz hata, devam et
            }
          }
        }

        // Use WeeklyXpService for comprehensive XP and quiz tracking
        try {
          // Add XP (includes weekly tracking)
          await sessionService.addXp(earnedXp);
          
          // Add quiz completion (includes weekly tracking)
          await WeeklyXpService.addQuizCompletion(uid);
          
          // Log XP and quiz completion
          debugPrint('[XP] +$earnedXp → totalXp with weekly tracking (uid=$uid)');
          debugPrint('[QUIZ] +1 → totalQuizzesCompleted with weekly tracking (uid=$uid)');
        } catch (e) {
          debugPrint('Error updating XP and quiz stats: $e');
        }

        try {
          await sessionService.updateLeaderboardAfterQuiz(_score);
        } catch (e) {
          // sessiz hata, devam et
        }

        if (mounted) {
          showLexiflowToast(
            context,
            ToastType.success,
            'Quiz tamamlandı! +$earnedXp XP kazandınız',
          );
        }
      }

      try {
        await _statistics.recordActivity(
          userId: uid ?? 'guest',
          xpEarned: earnedXp,
          quizzesCompleted: 1,
        );
      } catch (e) {
        // sessiz hata, devam et
      }

      if (uid != null) {
        try {
          await _statistics.logSessionComplete(
            userId: uid,
            totalWords: _quizWords.length,
            sessionTime: Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - (_questionShownAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch)),
          );
        } catch (e) {
          // sessiz hata, devam et
        }
      } else {
        final accuracy = ((_score / _quizWords.length) * 100).round();
        AnalyticsService.logQuizCompleted(
          totalQuestions: _quizWords.length,
          correctAnswers: _score,
          accuracy: accuracy,
          earnedXp: earnedXp,
        );
      }

      _quizResults.forEach((word, isCorrect) async {
        try {
          final rt = _responseTimesMs[word] ?? 0;
          final quality = _qualities[word] ?? (isCorrect ? 2 : 0);
          
          await SRSService.updateAfterAnswer(
            word: word,
            quality: quality,
            responseTimeMs: rt,
          );
          
          Logger.d(
            'SRS updated: ${word.word} - quality: $quality, rt: ${rt}ms',
            'QuizScreen',
          );
        } catch (e) {
          Logger.e('Failed to update SRS for ${word.word}: $e', 'QuizScreen');
        }
      });
    } catch (e) {
      if (!mounted) return;
      
      showLexiflowToast(
        context,
        ToastType.error,
        'Quiz tamamlandı ancak XP kaydedilemedi',
      );
    }
  }

  void _showFeedback(bool isCorrect) {
    // Implementation for showing feedback
  }

  Future<int?> _showQualityPrompt() async {
    if (!mounted) return 2;
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Bu kelimeyi ne kadar iyi biliyorsunuz?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQualityOption(0, 'Hiç bilmiyorum', Icons.sentiment_very_dissatisfied),
            _buildQualityOption(1, 'Zor hatırlıyorum', Icons.sentiment_dissatisfied),
            _buildQualityOption(2, 'İyi biliyorum', Icons.sentiment_satisfied),
            _buildQualityOption(3, 'Çok iyi biliyorum', Icons.sentiment_very_satisfied),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption(int quality, String text, IconData icon) {
    return ListTile(
      leading: Icon(icon),
      title: Text(text),
      onTap: () => Navigator.of(context).pop(quality),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = locator<SessionService>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (sessionService.isGuest) {
      return const GuestLoginPrompt(
        title: 'Giriş Yapın',
        message: 'Quiz oynamak için giriş yapmanız gerekiyor.',
        icon: Icons.quiz,
      );
    }

    // Show loading state during initialization
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Quiz'),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: Container(
          color: theme.colorScheme.surface,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Quiz hazırlanıyor...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show error state
    if (_hasError) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Quiz'),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: Container(
          color: theme.colorScheme.surface,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage.isNotEmpty ? _errorMessage : 'Failed to load quiz',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _initQuiz();
                  },
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show empty state if no quiz words
    if (_quizWords.isEmpty) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Quiz'),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: Container(
          color: theme.colorScheme.surface,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quiz için yeterli kelime bulunamadı',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'En az 4 favori kelime eklemelisiniz',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final progress = (_currentIndex + 1) / _quizWords.length;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Quiz'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_score',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: theme.colorScheme.surface,
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '${_currentIndex + 1}',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                'of ${_quizWords.length}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.secondaryContainer,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _correctWord?.word ?? '',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'What does this mean?',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Builder(
                        builder: (context) {
                          final optionCount = _options.length;
                          const spacing = 12.0;
                          
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _options.length,
                            itemBuilder: (context, index) {
                              final option = _options[index];
                              final isCorrect = option.word == _correctWord!.word;
                              final isSelected = _selectedWord?.word == option.word;
                              
                              Color? backgroundColor;
                              Color? borderColor;
                              if (_isAnswered) {
                                if (isCorrect) {
                                  backgroundColor = Colors.green.withOpacity(0.1);
                                  borderColor = Colors.green;
                                } else if (isSelected) {
                                  backgroundColor = Colors.red.withOpacity(0.1);
                                  borderColor = Colors.red;
                                }
                              }
                              
                              return Container(
                                margin: EdgeInsets.only(
                                  bottom: index < _options.length - 1 ? spacing : 0,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _isAnswered
                                        ? null
                                        : () => _checkAnswer(option),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: backgroundColor ??
                                            (_isAnswered && isCorrect
                                                ? Colors.green.withOpacity(0.1)
                                                : _isAnswered && isSelected
                                                    ? Colors.red.withOpacity(0.1)
                                                    : theme.colorScheme.surface),
                                        border: Border.all(
                                          color: borderColor ??
                                              (_isAnswered &&
                                                  isCorrect
                                                  ? Colors.green
                                                  : _isAnswered && isSelected
                                                      ? Colors.red
                                                      : theme.colorScheme.outline.withOpacity(0.3)),
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        option.meaning,
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: pi / 2, // down
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.3,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
