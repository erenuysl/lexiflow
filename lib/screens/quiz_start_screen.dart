import 'package:flutter/material.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import '../services/quiz_generator.dart';
import '../widgets/lexiflow_toast.dart';
import '../utils/design_system.dart';
import '../di/locator.dart';

class QuizStartScreen extends StatefulWidget {
  final String? categoryKey;
  final String? categoryName;
  final String? categoryIcon;

  const QuizStartScreen({
    super.key,
    this.categoryKey,
    this.categoryName,
    this.categoryIcon,
  });

  @override
  State<QuizStartScreen> createState() => _QuizStartScreenState();
}

class _QuizStartScreenState extends State<QuizStartScreen> {
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

      if (widget.categoryKey == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Kategori bilgisi eksik';
        });
        return;
      }

      // kategori kelimelerini yükle
      final categoryWords = await wordService.getCategoryWords(widget.categoryKey!);
      
      if (!QuizGenerator.canGenerateQuiz(categoryWords)) {
        setState(() {
          _isLoading = false;
          _errorMessage = QuizGenerator.getInsufficientWordsMessage(categoryWords.length);
        });
        return;
      }

      final quizData = QuizGenerator.generateQuiz(
        sourceWords: categoryWords,
        quizType: 'category_${widget.categoryKey}',
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
            'categoryKey': widget.categoryKey,
            'categoryName': widget.categoryName,
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
        title: Text(widget.categoryName ?? 'Kategori Quiz'),
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
        if (widget.categoryIcon != null) ...[
          Text(
            widget.categoryIcon!,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
        ],
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          '${widget.categoryName ?? 'Kategori'} quiz\'i hazırlanıyor...',
          style: AppTextStyles.body1.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
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
          if (widget.categoryIcon != null) ...[
            Text(
              widget.categoryIcon!,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
          ],
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