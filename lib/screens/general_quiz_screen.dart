import 'package:flutter/material.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/quiz_generator.dart';
import '../widgets/lexiflow_toast.dart';
import '../utils/design_system.dart';
import '../di/locator.dart';

class GeneralQuizScreen extends StatefulWidget {
  const GeneralQuizScreen({super.key});

  @override
  State<GeneralQuizScreen> createState() => _GeneralQuizScreenState();
}

class _GeneralQuizScreenState extends State<GeneralQuizScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  Future<void> _initializeQuiz() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final wordService = locator<WordService>();
      final userService = locator<UserService>();

      // 1K kelimelerden quiz oluştur
      final allWords = await wordService.getAllWordsFromLocal();
      
      if (!QuizGenerator.canGenerateQuiz(allWords)) {
        setState(() {
          _isLoading = false;
          _errorMessage = QuizGenerator.getInsufficientWordsMessage(allWords.length);
        });
        return;
      }

      final quizData = QuizGenerator.generateQuiz(
        sourceWords: allWords,
        quizType: 'general_1k',
      );

      if (quizData == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Quiz oluşturulamadı. Lütfen tekrar deneyin.';
        });
        return;
      }

      // Quiz ekranına geç
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/quiz/play',
          arguments: {
            'quizData': quizData,
          },
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bir hata oluştu: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('1K Kelimeden Quiz'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: _isLoading
            ? _buildLoadingWidget()
            : _buildErrorWidget(),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          'Quiz hazırlanıyor...',
          style: AppTextStyles.body1.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Quiz Başlatılamadı',
            style: AppTextStyles.title1.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Bilinmeyen bir hata oluştu',
            style: AppTextStyles.body2.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Geri Dön'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _initializeQuiz,
            child: Text(
              'Tekrar Dene',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}