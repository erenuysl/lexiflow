import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../utils/logger.dart';
import 'quiz_screen.dart';

class LearnedQuizScreen extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final AdService adService;
  final List<Word> learnedWords;

  const LearnedQuizScreen({
    super.key,
    required this.wordService,
    required this.userService,
    required this.adService,
    required this.learnedWords,
  });

  @override
  State<LearnedQuizScreen> createState() => _LearnedQuizScreenState();
}

class _LearnedQuizScreenState extends State<LearnedQuizScreen> {
  static const String _tag = 'LearnedQuizScreen';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Öğrenilenler Quiz',
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
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF4ADE80),
                        Color(0xFF16A34A),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4ADE80).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'Öğrenilenler Quiz',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Öğrendiğin kelimelerle kendini test et!',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

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
                        Row(
                          children: [
                            Icon(
                              Icons.school,
                              color: const Color(0xFF16A34A),
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.learnedWords.length} Öğrenilen Kelime',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                  ),
                                  Text(
                                    'Öğrendiğin kelimelerle quiz çöz',
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

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4ADE80).withOpacity(0.1),
                                const Color(0xFF16A34A).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Sadece öğrendiğin kelimelerden rastgele sorular oluşturulur.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                if (_isLoading)
                  CircularProgressIndicator(
                    color: const Color(0xFF16A34A),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.learnedWords.length >= 4
                              ? [
                                  const Color(0xFF34D399),
                                  const Color(0xFF059669),
                                ]
                              : [
                                  Colors.grey.shade400,
                                  Colors.grey.shade500,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: widget.learnedWords.length >= 4
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF34D399).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: widget.learnedWords.length >= 4 ? _startQuiz : null,
                        icon: Icon(
                          widget.learnedWords.length >= 4 
                              ? Icons.school_rounded 
                              : Icons.lock_outline,
                          size: 28,
                        ),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            widget.learnedWords.length >= 4 
                                ? '🎓 Quiz Başlat'
                                : 'Quiz için ${4 - widget.learnedWords.length} kelime daha gerekli',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
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

  Future<void> _startQuiz() async {
    Logger.i('Starting learned quiz with ${widget.learnedWords.length} words', _tag);
    
    setState(() => _isLoading = true);

    try {
      if (widget.learnedWords.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Öğrenilen kelime bulunamadı.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // favori olmayan öğrenilen kelimeleri filtrele
      final filteredLearnedWords = widget.learnedWords
          .where((word) => !word.isFavorite)
          .toList();

      if (filteredLearnedWords.length < 4) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Quiz için yeterli öğrenilen kelime yok.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      Logger.d('Attempting to show rewarded ad', _tag);
      
      final adShown = await widget.adService.showRewardedAd();
      
      if (!adShown) {
        Logger.w('Rewarded ad not available or failed to show', _tag);
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Reklam hazır değil. Lütfen tekrar dene.')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      Logger.success('Rewarded ad shown successfully', _tag);
      
      if (!mounted) return;

      filteredLearnedWords.shuffle();
      final quizWords = filteredLearnedWords.take(10).toList();

      await AnalyticsService.logQuizStarted(
        quizType: 'learned',
        wordCount: quizWords.length,
      );

      Logger.i('Navigating to quiz screen with ${quizWords.length} learned words', _tag);
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            wordService: widget.wordService,
            userService: widget.userService,
            quizWords: quizWords,
            quizType: 'learned',
          ),
        ),
      );
      Logger.d('Returned from quiz screen', _tag);
    } catch (e, stackTrace) {
      Logger.e('Failed to start learned quiz', e, stackTrace, _tag);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}