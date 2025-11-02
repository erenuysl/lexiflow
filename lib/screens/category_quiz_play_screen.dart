import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/quiz_generator.dart';
import 'quiz_screen.dart';

class CategoryQuizPlayScreen extends StatefulWidget {
  final WordService wordService;
  final UserService userService;

  const CategoryQuizPlayScreen({
    super.key,
    required this.wordService,
    required this.userService,
  });

  @override
  State<CategoryQuizPlayScreen> createState() => _CategoryQuizPlayScreenState();
}

class _CategoryQuizPlayScreenState extends State<CategoryQuizPlayScreen> {
  QuizData? _quizData;
  bool _isLoading = true;
  String? _error;
  String? _categoryKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    if (args?['quizData'] != null) {
      // Quiz data already generated, use it directly
      setState(() {
        _quizData = args!['quizData'] as QuizData;
        _categoryKey = args['categoryKey'] as String?;
        _isLoading = false;
      });
    } else {
      // Fallback: generate quiz from category (shouldn't happen with new flow)
      final categoryKey = args?['categoryKey'] as String?;
      if (categoryKey == null) {
        setState(() {
          _error = 'Kategori bilgisi bulunamadı';
          _isLoading = false;
        });
        return;
      }

      try {
        final words = await widget.wordService.getCategoryWords(categoryKey);
        if (!QuizGenerator.canGenerateQuiz(words)) {
          setState(() {
            _error = QuizGenerator.getInsufficientWordsMessage(words.length);
            _isLoading = false;
          });
          return;
        }

        final quizData = QuizGenerator.generateQuiz(
          sourceWords: words,
          quizType: 'category_$categoryKey',
        );
        setState(() {
          _quizData = quizData;
          _categoryKey = categoryKey;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _error = 'Quiz oluşturulurken hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen(context);
    }

    if (_error != null) {
      return _buildErrorScreen(context, _error!);
    }

    if (_quizData == null) {
      return _buildErrorScreen(context, 'Quiz verisi bulunamadı');
    }

    return QuizScreen(
      wordService: widget.wordService,
      userService: widget.userService,
      quizWords: _quizData!.questions.map((q) => q.correctWord).toList(),
      quizType: 'category_quiz',
      categoryKey: _categoryKey,
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Hazırlanıyor')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Quiz sorular hazırlanıyor...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String error) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Hatası')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: colorScheme.error),
              const SizedBox(height: 24),
              Text(
                'Quiz Başlatılamadı',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
