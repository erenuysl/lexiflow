import 'dart:math';
import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../services/word_loader.dart';
import '../services/session_service.dart';
import '../utils/logger.dart';

class FillBlanksQuizScreen extends StatefulWidget {
  final String category;

  const FillBlanksQuizScreen({
    super.key,
    required this.category,
  });

  @override
  State<FillBlanksQuizScreen> createState() => _FillBlanksQuizScreenState();
}

class _FillBlanksQuizScreenState extends State<FillBlanksQuizScreen> {
  List<Word> _words = [];
  List<FillBlanksQuestion> _questions = [];
  int _currentQuestionIndex = 0;
  int _correctAnswers = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int? _selectedAnswerIndex;
  bool _showResult = false;
  bool _isAnswered = false;

  // oturum boyunca kullanılan kelimeleri takip et
  static final Set<String> _usedWordsInSession = <String>{};
  static const int _maxQuestions = 10;

  @override
  void initState() {
    super.initState();
    _loadWordsAndGenerateQuiz();
  }

  // oturum sıfırlama metodu - kullanılan kelimeleri temizle
  static void resetSession() {
    _usedWordsInSession.clear();
  }

  Future<void> _loadWordsAndGenerateQuiz() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final allWords = await WordLoader.loadCategoryWords(widget.category);
      
      // kullanılmamış kelimeleri filtrele
      final availableWords = allWords.where((word) => 
        !_usedWordsInSession.contains(word.word)).toList();
      
      if (availableWords.length < _maxQuestions) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Bu kategoride yeterli yeni kelime bulunamadı. '
              'En az $_maxQuestions kelime gerekli, ${availableWords.length} mevcut.\n\n'
              'Kelimeleri sıfırlamak için "Kelimeleri Sıfırla" butonuna tıklayın.';
          _isLoading = false;
        });
        return;
      }

      // rastgele 10 kelime seç
      final random = Random();
      availableWords.shuffle(random);
      final selectedWords = availableWords.take(_maxQuestions).toList();
      
      // seçilen kelimeleri kullanılan listesine ekle
      for (final word in selectedWords) {
        _usedWordsInSession.add(word.word);
      }

      setState(() {
        _words = selectedWords;
        _isLoading = false;
      });

      _generateQuestions();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Kelimeler yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  void _generateQuestions() async {
    final random = Random();
    _questions = [];
    
    // tüm kategori kelimelerini yanlış seçenekler için yükle
    final allCategoryWords = await WordLoader.loadCategoryWords(widget.category);

    for (int i = 0; i < _words.length; i++) {
      final word = _words[i];
      final correctAnswer = word.word;
      
      // aynı kategoriden farklı kelimeler al (doğru cevap hariç)
      final otherWords = allCategoryWords
          .where((w) => w.word != correctAnswer)
          .toList();
      otherWords.shuffle(random);
      
      // 3 yanlış seçenek al
      final wrongOptions = otherWords.take(3).map((w) => w.word).toList();
      
      // tüm seçenekleri karıştır
      final allOptions = <String>[correctAnswer, ...wrongOptions];
      allOptions.shuffle(random);
      
      final correctIndex = allOptions.indexOf(correctAnswer);
      
      // basit İngilizce cümle oluştur
      final sentence = _generateSentence(word);
      
      _questions.add(FillBlanksQuestion(
        sentence: sentence,
        correctAnswer: correctAnswer,
        options: allOptions,
        correctIndex: correctIndex,
        word: word,
      ));
    }
  }

  String _generateSentence(Word word) {
    final sentences = [
      "I need to _____ this task carefully.",
      "The _____ is very important for success.",
      "She decided to _____ the opportunity.",
      "This _____ will help you understand better.",
      "We should _____ our goals clearly.",
      "The _____ was exactly what we needed.",
      "He tried to _____ the problem quickly.",
      "That _____ made a big difference.",
      "They want to _____ something new.",
      "The _____ is ready for use.",
    ];
    
    final random = Random();
    return sentences[random.nextInt(sentences.length)];
  }

  void _selectAnswer(int index) {
    if (_isAnswered) return;
    
    setState(() {
      _selectedAnswerIndex = index;
      _isAnswered = true;
      _showResult = true;
      
      if (index == _questions[_currentQuestionIndex].correctIndex) {
        _correctAnswers++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _showResult = false;
        _isAnswered = false;
      });
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() async {
    // quiz tamamlandı, sonuç ekranına git
    int earnedXp = SessionService.calculateQuizXp('fill_blanks', _correctAnswers);
    
    // XP'yi ekle
    await SessionService().addQuizXp('fill_blanks', _correctAnswers);
    
    Logger.i('Fill Blanks Quiz completed: $_correctAnswers/${_questions.length} correct, +$earnedXp XP', 'FillBlanksQuiz');
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => FillBlanksQuizResultScreen(
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
          'Boşluk Doldurma Quiz',
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Kelimeler yükleniyor...'),
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
                'Hata',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // kelime sıfırlama butonu ekle
              if (_errorMessage.contains('yeterli yeni kelime')) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    resetSession();
                    _loadWordsAndGenerateQuiz();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Kelimeleri Sıfırla'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
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
    FillBlanksQuestion question = _questions[_currentQuestionIndex];
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ilerleme çubuğu
          Row(
            children: [
              Text(
                'Soru ${_currentQuestionIndex + 1}/${_questions.length}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const Spacer(),
              Text(
                'Doğru: $_correctAnswers',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
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
                  'Boşluğu doldurun:',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  question.sentence,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Türkçe anlamı: ${question.word.tr}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // seçenekler
          Expanded(
            child: ListView.builder(
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                return _buildOptionCard(index, question.options[index], question.correctIndex);
              },
            ),
          ),

          // sonraki soru butonu
          if (_showResult) ...[
            const SizedBox(height: 16),
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
                _currentQuestionIndex < _questions.length - 1 ? 'Sonraki Soru' : 'Sonuçları Gör',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index, String option, int correctIndex) {
    bool isSelected = _selectedAnswerIndex == index;
    bool isCorrect = index == correctIndex;
    bool showColors = _showResult;

    Color? backgroundColor;
    Color? borderColor;
    Color? textColor;

    if (showColors) {
      if (isCorrect) {
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green;
        textColor = Colors.green;
      } else if (isSelected && !isCorrect) {
        backgroundColor = Colors.red.withOpacity(0.1);
        borderColor = Colors.red;
        textColor = Colors.red;
      } else {
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        borderColor = Theme.of(context).colorScheme.outline.withOpacity(0.3);
        textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
      }
    } else {
      backgroundColor = isSelected 
        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
      borderColor = isSelected 
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline.withOpacity(0.3);
      textColor = isSelected 
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAnswered ? null : () => _selectAnswer(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor!, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: showColors && isCorrect 
                      ? Colors.green 
                      : showColors && isSelected && !isCorrect
                        ? Colors.red
                        : isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    border: Border.all(
                      color: showColors && isCorrect 
                        ? Colors.green 
                        : showColors && isSelected && !isCorrect
                          ? Colors.red
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: showColors && isCorrect
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : showColors && isSelected && !isCorrect
                      ? const Icon(Icons.close, color: Colors.white, size: 16)
                      : isSelected
                        ? Icon(Icons.circle, color: Theme.of(context).colorScheme.onPrimary, size: 12)
                        : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    option,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
}

class FillBlanksQuestion {
  final String sentence;
  final String correctAnswer;
  final List<String> options;
  final int correctIndex;
  final Word word;

  FillBlanksQuestion({
    required this.sentence,
    required this.correctAnswer,
    required this.options,
    required this.correctIndex,
    required this.word,
  });
}

class FillBlanksQuizResultScreen extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;
  final int earnedXp;
  final String category;

  const FillBlanksQuizResultScreen({
    super.key,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.earnedXp,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    double percentage = (correctAnswers / totalQuestions) * 100;
    String performanceText = _getPerformanceText(percentage);
    String performanceEmoji = _getPerformanceEmoji(percentage);

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
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // performans emojisi
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          border: Border.all(
                            color: _getPerformanceColor(percentage).withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: Text(
                          performanceEmoji,
                          style: const TextStyle(fontSize: 80),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // başlık
                      Text(
                        'Quiz Tamamlandı!',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // performans metni
                      Text(
                        performanceText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _getPerformanceColor(percentage),
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // sonuç kartları
                      _buildResultCard(
                        context,
                        'Doğru Cevap',
                        '$correctAnswers/$totalQuestions',
                        Colors.green,
                        Icons.check_circle,
                      ),
                      const SizedBox(height: 16),
                      _buildResultCard(
                        context,
                        'Başarı Oranı',
                        '${percentage.toStringAsFixed(0)}%',
                        _getPerformanceColor(percentage),
                        Icons.trending_up,
                      ),
                      const SizedBox(height: 16),
                      _buildResultCard(
                        context,
                        'Kazanılan XP',
                        '+$earnedXp XP',
                        Colors.amber,
                        Icons.star,
                      ),
                      const SizedBox(height: 32),

                      // kategori bilgisi
                      Text(
                        'Kategori: $category',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // bottom padding için alan bırak
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      persistentFooterButtons: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Ana Menü'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FillBlanksQuizScreen(category: category),
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
                  child: const Text('Tekrar Oyna'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(BuildContext context, String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
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

  String _getPerformanceText(double percentage) {
    if (percentage >= 90) return 'Mükemmel!';
    if (percentage >= 80) return 'Harika!';
    if (percentage >= 70) return 'İyi!';
    if (percentage >= 60) return 'Fena Değil';
    if (percentage >= 50) return 'Orta';
    return 'Daha Çok Çalışmalısın';
  }

  String _getPerformanceEmoji(double percentage) {
    if (percentage >= 90) return '🏆';
    if (percentage >= 80) return '🎉';
    if (percentage >= 70) return '😊';
    if (percentage >= 60) return '🙂';
    if (percentage >= 50) return '😐';
    return '😔';
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}