import 'package:flutter/material.dart';
import 'dart:math';
import '../models/word_model.dart';
import '../services/word_loader.dart';
import '../services/session_service.dart';
import '../utils/logger.dart';

class TranslationQuizScreen extends StatefulWidget {
  final String category;

  const TranslationQuizScreen({
    super.key,
    required this.category,
  });

  @override
  State<TranslationQuizScreen> createState() => _TranslationQuizScreenState();
}

class _TranslationQuizScreenState extends State<TranslationQuizScreen> {
  List<Word> _words = [];
  List<TranslationQuestion> _questions = [];
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool? _selectedAnswer; // true for Doğru, false for Yanlış
  bool _showResult = false;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _loadWordsAndGenerateQuiz();
  }

  Future<void> _loadWordsAndGenerateQuiz() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // kategori kelimelerini yükle
      List<Word> categoryWords = await WordLoader.loadCategoryWords(widget.category);
      
      if (categoryWords.length < 10) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Bu kategoride yeterli kelime yok. En az 10 kelime gerekli.';
          _isLoading = false;
        });
        return;
      }

      // 10 rastgele kelime seç
      categoryWords.shuffle();
      _words = categoryWords.take(10).toList();

      // quiz sorularını oluştur
      _generateQuestions();

      setState(() {
        _isLoading = false;
      });

      Logger.i('Çeviri Quiz başlatıldı: ${_words.length} soru, kategori: ${widget.category}');
    } catch (e) {
      Logger.e('Çeviri Quiz yükleme hatası: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Kelimeler yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  void _generateQuestions() {
    _questions.clear();
    final random = Random();
    
    for (int i = 0; i < _words.length; i++) {
      Word currentWord = _words[i];
      
      // %50 şansla doğru veya yanlış çeviri göster
      bool isCorrectTranslation = random.nextBool();
      String displayedMeaning;
      
      if (isCorrectTranslation) {
        displayedMeaning = currentWord.meaning;
      } else {
        // yanlış anlam için diğer kelimelerden rastgele bir tane seç
        List<Word> otherWords = _words.where((w) => w.word != currentWord.word).toList();
        if (otherWords.isNotEmpty) {
          otherWords.shuffle();
          displayedMeaning = otherWords.first.meaning;
        } else {
          // fallback: doğru anlamı göster
          displayedMeaning = currentWord.meaning;
          isCorrectTranslation = true;
        }
      }
      
      _questions.add(TranslationQuestion(
        word: currentWord.word,
        displayedMeaning: displayedMeaning,
        isCorrect: isCorrectTranslation,
      ));
    }
  }

  void _selectAnswer(bool answer) {
    if (_isAnswered) return;
    
    setState(() {
      _selectedAnswer = answer;
      _isAnswered = true;
      _showResult = true;
      
      // doğru cevap kontrolü
      bool isCorrectAnswer = answer == _questions[_currentQuestionIndex].isCorrect;
      if (isCorrectAnswer) {
        _correctAnswers++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _showResult = false;
        _isAnswered = false;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() async {
    // quiz tamamlandı, sonuç ekranına git
    int earnedXp = SessionService.calculateQuizXp('translation', _correctAnswers);
    
    // XP'yi ekle
    await SessionService().addQuizXp('translation', _correctAnswers);
    
    Logger.i('Translation Quiz completed: $_correctAnswers/${_questions.length} correct, +$earnedXp XP', 'TranslationQuiz');
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => TranslationQuizResultScreen(
            correctAnswers: _correctAnswers,
            totalQuestions: _questions.length,
            earnedXp: earnedXp,
            category: widget.category,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Çeviri Quiz',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Kelimeler yükleniyor...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildQuizContent();
  }

  Widget _buildQuizContent() {
    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ilerleme bilgisi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soru ${_currentQuestionIndex + 1}/${_questions.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                'Doğru: $_correctAnswers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ilerleme çubuğu
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),

          // soru kartı
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Bu çeviri doğru mu?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // kelime
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    question.word,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // çeviri ok
                Icon(
                  Icons.arrow_downward,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  size: 32,
                ),
                
                const SizedBox(height: 16),
                
                // gösterilen anlam
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    question.displayedMeaning,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          // cevap butonları
          Row(
            children: [
              Expanded(
                child: _buildAnswerButton(
                  text: 'Yanlış',
                  answer: false,
                  icon: Icons.close,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAnswerButton(
                  text: 'Doğru',
                  answer: true,
                  icon: Icons.check,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // sonraki soru butonu
          if (_showResult)
            ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentQuestionIndex < _questions.length - 1 
                    ? 'Sonraki Soru' 
                    : 'Sonuçları Gör',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton({
    required String text,
    required bool answer,
    required IconData icon,
    required Color color,
  }) {
    bool isSelected = _selectedAnswer == answer;
    bool isCorrectAnswer = answer == _questions[_currentQuestionIndex].isCorrect;
    
    Color buttonColor;
    Color textColor;
    IconData? feedbackIcon;
    
    if (!_showResult) {
      // henüz cevap verilmemiş
      buttonColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      textColor = Theme.of(context).colorScheme.onSurface;
    } else if (isSelected) {
      // seçilen cevap
      if (isCorrectAnswer) {
        buttonColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green;
        feedbackIcon = Icons.check_circle;
      } else {
        buttonColor = Colors.red.withOpacity(0.2);
        textColor = Colors.red;
        feedbackIcon = Icons.cancel;
      }
    } else if (isCorrectAnswer) {
      // doğru cevap (seçilmemiş)
      buttonColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
      feedbackIcon = Icons.check_circle_outline;
    } else {
      // yanlış cevap (seçilmemiş)
      buttonColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    }

    return Container(
      decoration: BoxDecoration(
        color: buttonColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
              ? (isCorrectAnswer ? Colors.green : Colors.red)
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: _isAnswered ? null : () => _selectAnswer(answer),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                feedbackIcon ?? icon,
                color: textColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// soru modeli
class TranslationQuestion {
  final String word;
  final String displayedMeaning;
  final bool isCorrect;

  TranslationQuestion({
    required this.word,
    required this.displayedMeaning,
    required this.isCorrect,
  });
}

// sonuç ekranı
class TranslationQuizResultScreen extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;
  final int earnedXp;
  final String category;

  const TranslationQuizResultScreen({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.earnedXp,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (correctAnswers / totalQuestions * 100).round();
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Quiz Sonucu',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // performans göstergesi
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getPerformanceColor(percentage).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _getPerformanceEmoji(percentage),
                      style: const TextStyle(fontSize: 80),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getPerformanceText(percentage),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: _getPerformanceColor(percentage),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '%$percentage Başarı',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // istatistikler
              _buildResultCard(
                context,
                'Doğru Cevaplar',
                '$correctAnswers/$totalQuestions',
                Icons.check_circle,
                Colors.green,
              ),
              
              const SizedBox(height: 12),
              
              _buildResultCard(
                context,
                'Kazanılan XP',
                '+$earnedXp XP',
                Icons.star,
                Colors.amber,
              ),
              
              const SizedBox(height: 12),
              
              _buildResultCard(
                context,
                'Kategori',
                category,
                Icons.category,
                Theme.of(context).colorScheme.primary,
              ),

              const Spacer(),

              // butonlar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ana Menü',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TranslationQuizScreen(
                              category: category,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Tekrar Oyna',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPerformanceText(int percentage) {
    if (percentage >= 90) return 'Mükemmel!';
    if (percentage >= 80) return 'Harika!';
    if (percentage >= 70) return 'İyi!';
    if (percentage >= 60) return 'Fena Değil';
    return 'Daha İyi Olabilir';
  }

  String _getPerformanceEmoji(int percentage) {
    if (percentage >= 90) return '🏆';
    if (percentage >= 80) return '🎉';
    if (percentage >= 70) return '😊';
    if (percentage >= 60) return '🙂';
    return '😐';
  }

  Color _getPerformanceColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}