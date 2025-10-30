import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../services/word_service.dart';
import '../services/user_service.dart';
import 'quiz_screen.dart';

class CategoryQuizPlayScreen extends StatefulWidget {
  final String? category;
  final String? categoryName;
  final List<Word>? categoryWords;
  final WordService wordService;
  final UserService userService;

  const CategoryQuizPlayScreen({
    super.key,
    this.category,
    this.categoryName,
    this.categoryWords,
    required this.wordService,
    required this.userService,
  });

  @override
  State<CategoryQuizPlayScreen> createState() => _CategoryQuizPlayScreenState();
}

class _CategoryQuizPlayScreenState extends State<CategoryQuizPlayScreen> {
  List<Word> _categoryWords = [];
  bool _isLoading = true;
  String _category = '';
  String _categoryName = '';
  Color? _categoryColor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCategoryData();
  }

  Future<void> _loadCategoryData() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    
    _category = args?['category'] ?? widget.category ?? '';
    _categoryName = args?['title'] ?? widget.categoryName ?? '';
    _categoryColor = args?['categoryColor'] as Color?;

    if (_category.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Load all words and filter by category
      final allWords = widget.wordService.getAllWords();
      final filteredWords = allWords.where((word) => word.category == _category).toList();
      
      setState(() {
        _categoryWords = filteredWords;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kelimeler yüklenirken hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen(context);
    }

    if (_categoryWords.length < 4) {
      return _buildInsufficientWordsScreen(context);
    }

    final filteredWords = _prepareQuizWords();

    return QuizScreen(
      wordService: widget.wordService,
      userService: widget.userService,
      quizWords: filteredWords,
      quizType: 'category_$_category',
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: _categoryColor?.withOpacity(0.1),
      appBar: AppBar(
        title: Text('$_categoryName Quiz'),
        backgroundColor: _categoryColor?.withOpacity(0.2),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  List<Word> _prepareQuizWords() {
    // Shuffle and limit to 10 words for optimal quiz experience
    final shuffledWords = List<Word>.from(_categoryWords);
    shuffledWords.shuffle();
    
    // Take up to 10 words for the quiz
    final quizWords = shuffledWords.take(10).toList();
    
    return quizWords;
  }

  Widget _buildInsufficientWordsScreen(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _categoryColor?.withOpacity(0.1),
      appBar: AppBar(
        title: Text('$_categoryName Quiz'),
        backgroundColor: _categoryColor?.withOpacity(0.2),
        foregroundColor: colorScheme.onSurface,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 80,
                color: _categoryColor ?? colorScheme.outline,
              ),
              const SizedBox(height: 24),
              Text(
                'Bu kategoride yeterli kelime yok ⚠️',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Quiz oluşturmak için en az 4 kelime gerekli.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Mevcut kelime sayısı: ${_categoryWords.length}',
                style: textTheme.bodyMedium?.copyWith(
                  color: _categoryColor ?? colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Geri Dön'),
                style: FilledButton.styleFrom(
                  backgroundColor: _categoryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}