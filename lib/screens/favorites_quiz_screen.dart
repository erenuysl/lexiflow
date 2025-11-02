import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../models/category_theme.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/ad_service.dart';
import '../services/analytics_service.dart';
import '../utils/logger.dart';
import 'quiz_screen.dart';

class FavoritesQuizScreen extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final AdService adService;
  final List<Word> favoriteWords;

  const FavoritesQuizScreen({
    super.key,
    required this.wordService,
    required this.userService,
    required this.adService,
    required this.favoriteWords,
  });

  @override
  State<FavoritesQuizScreen> createState() => _FavoritesQuizScreenState();
}

class _FavoritesQuizScreenState extends State<FavoritesQuizScreen> {
  static const String _tag = 'FavoritesQuizScreen';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // favoriler kategorisi temasını kullan
    final theme = categoryThemes['favorites'] ?? 
      const CategoryTheme(
        emoji: '❤️',
        color: Colors.pinkAccent,
        title: 'Favoriler',
        description: 'Favori kelimelerinle pratik yap!',
      );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '${theme.emoji} ${theme.title}',
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
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.withOpacity(0.2),
                        Colors.pink.withOpacity(0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite,
                    size: 80,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'Favoriler Quiz',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

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
                                    '${widget.favoriteWords.length} Favori Kelime',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                  ),
                                  Text(
                                    'Favori kelimelerinle quiz çöz',
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
                                Colors.red.withOpacity(0.1),
                                Colors.pink.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.favorite,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '💖 Favori kelimelerinle pratik yap!',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
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
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.red,
                            Colors.pink,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _startQuiz,
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Quiz Başlat',
                            style: TextStyle(
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
    Logger.i('Starting favorites quiz with ${widget.favoriteWords.length} words', _tag);
    
    setState(() => _isLoading = true);

    try {
      if (widget.favoriteWords.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Favori kelime bulunamadı.')),
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

      await AnalyticsService.logFavoritesQuizStarted(
        favoriteCount: widget.favoriteWords.length,
      );

      Logger.i('Navigating to quiz screen with ${widget.favoriteWords.length} favorite words', _tag);
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            wordService: widget.wordService,
            userService: widget.userService,
            quizWords: widget.favoriteWords,
          ),
        ),
      );
      Logger.d('Returned from quiz screen', _tag);
    } catch (e, stackTrace) {
      Logger.e('Failed to start favorites quiz', e, stackTrace, _tag);
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
