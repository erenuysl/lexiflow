import 'package:flutter/material.dart';
import 'dart:math';
import '../models/word_model.dart';
import '../models/category_theme.dart';
import '../services/word_loader.dart';
import '../services/session_service.dart';
import '../utils/logger.dart';

class MatchingQuizScreen extends StatefulWidget {
  final String category;

  const MatchingQuizScreen({
    super.key,
    required this.category,
  });

  @override
  State<MatchingQuizScreen> createState() => _MatchingQuizScreenState();
}

class _MatchingQuizScreenState extends State<MatchingQuizScreen> with TickerProviderStateMixin {
  List<Word> _words = [];
  List<MatchingPair> _pairs = [];
  List<String> _leftColumn = [];
  List<String> _rightColumn = [];
  Set<int> _matchedPairs = {};
  int? _selectedLeftIndex;
  int? _selectedRightIndex;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showingFeedback = false;
  int _correctMatches = 0;
  
  // animasyon kontrolcüleri
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    
    // shake animasyonu için controller
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
    
    _loadWordsAndGenerateGame();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadWordsAndGenerateGame() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // kategori kelimelerini yükle
      List<Word> categoryWords = await WordLoader.loadCategoryWords(widget.category);
      
      if (categoryWords.length < 8) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Bu kategoride yeterli kelime yok. En az 8 kelime gerekli.';
          _isLoading = false;
        });
        return;
      }

      // 8 rastgele kelime seç
      categoryWords.shuffle();
      _words = categoryWords.take(8).toList();

      // eşleştirme çiftlerini oluştur
      _generatePairs();

      setState(() {
        _isLoading = false;
      });

      Logger.i('Eşleştirme quiz başlatıldı: ${_pairs.length} çift, kategori: ${widget.category}');
    } catch (e) {
      Logger.e('Eşleştirme quiz yükleme hatası: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Kelimeler yüklenirken hata oluştu: $e';
        _isLoading = false;
      });
    }
  }

  void _generatePairs() {
    _pairs.clear();
    _leftColumn.clear();
    _rightColumn.clear();
    
    // çiftleri oluştur
    for (int i = 0; i < _words.length; i++) {
      _pairs.add(MatchingPair(
        id: i,
        word: _words[i].word,
        meaning: _words[i].meaning,
      ));
    }
    
    // sol sütun (kelimeler) ve sağ sütun (anlamlar) oluştur
    _leftColumn = _pairs.map((pair) => pair.word).toList();
    _rightColumn = _pairs.map((pair) => pair.meaning).toList();
    
    // sütunları ayrı ayrı karıştır
    _leftColumn.shuffle();
    _rightColumn.shuffle();
  }

  void _selectItem(bool isLeft, int index) {
    if (_showingFeedback) return;
    
    setState(() {
      if (isLeft) {
        _selectedLeftIndex = _selectedLeftIndex == index ? null : index;
        if (_selectedLeftIndex != null && _selectedRightIndex != null) {
          _checkMatch();
        }
      } else {
        _selectedRightIndex = _selectedRightIndex == index ? null : index;
        if (_selectedLeftIndex != null && _selectedRightIndex != null) {
          _checkMatch();
        }
      }
    });
  }

  void _checkMatch() {
    if (_selectedLeftIndex == null || _selectedRightIndex == null) return;
    
    String selectedWord = _leftColumn[_selectedLeftIndex!];
    String selectedMeaning = _rightColumn[_selectedRightIndex!];
    
    // doğru eşleşmeyi bul
    MatchingPair? correctPair = _pairs.firstWhere(
      (pair) => pair.word == selectedWord,
    );
    
    bool isCorrect = correctPair.meaning == selectedMeaning;
    
    setState(() {
      _showingFeedback = true;
    });
    
    if (isCorrect) {
      // doğru eşleşme
      setState(() {
        _matchedPairs.add(_selectedLeftIndex!);
        _matchedPairs.add(_selectedRightIndex! + 100); // sağ sütun için offset
        _correctMatches++;
      });
      
      Logger.i('Doğru eşleşme: $selectedWord - $selectedMeaning');
      
      // tüm eşleşmeler tamamlandı mı?
      if (_correctMatches == _pairs.length) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _finishQuiz();
        });
        return;
      }
    } else {
      // yanlış eşleşme - titreşim animasyonu başlat
      _shakeController.forward().then((_) {
        _shakeController.reset();
      });
      
      Logger.w('Yanlış eşleşme: $selectedWord - $selectedMeaning');
    }
    
    // feedback'i temizle
    Future.delayed(Duration(milliseconds: isCorrect ? 500 : 1000), () {
      if (mounted) {
        setState(() {
          if (!isCorrect) {
            _selectedLeftIndex = null;
            _selectedRightIndex = null;
          }
          _showingFeedback = false;
        });
      }
    });
  }

  void _finishQuiz() async {
    // quiz tamamlandı, sonuç ekranına git
    int earnedXp = SessionService.calculateQuizXp('matching', _correctMatches);
    
    // XP'yi ekle
    await SessionService().addQuizXp('matching', _correctMatches);
    
    Logger.i('Matching Quiz completed: $_correctMatches/${_pairs.length} correct, +$earnedXp XP', 'MatchingQuiz');
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => MatchingQuizResultScreen(
            correctAnswers: _correctMatches,
            totalQuestions: _pairs.length,
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
    // kategori temasını al, yoksa varsayılan kullan
    final theme = categoryThemes[widget.category] ?? 
      const CategoryTheme(
        emoji: '🎯',
        color: Colors.blueAccent,
        title: 'Quiz',
        description: 'Hazırsan başlayalım!',
      );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '${theme.title} - Eşleştirme',
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
                'Hata',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
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
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    return _buildGameContent();
  }

  Widget _buildGameContent() {
    // kategori temasını al
    final theme = categoryThemes[widget.category] ?? 
      const CategoryTheme(
        emoji: '🎯',
        color: Colors.blueAccent,
        title: 'Quiz',
        description: 'Hazırsan başlayalım!',
      );

    return Column(
      children: [
        // modernize edilmiş üst bilgi bandı
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Eşleşen: $_correctMatches/${_pairs.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Kategori: ${theme.emoji} ${theme.title}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ince progress bar
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _correctMatches / _pairs.length,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade500,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // oyun alanı - SafeArea ve scroll ile
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // sol sütun (kelimeler)
                Expanded(
                  child: Column(
                    children: [
                      // sticky başlık
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Kelimeler',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: theme.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _leftColumn.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildMatchingCard(
                              _leftColumn[index],
                              index,
                              true,
                              _selectedLeftIndex == index,
                              _matchedPairs.contains(index),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // sağ sütun (anlamlar)
                Expanded(
                  child: Column(
                    children: [
                      // sticky başlık
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Anlamlar',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _rightColumn.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildMatchingCard(
                              _rightColumn[index],
                              index,
                              false,
                              _selectedRightIndex == index,
                              _matchedPairs.contains(index + 100),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMatchingCard(String text, int index, bool isLeft, bool isSelected, bool isMatched) {
    Color? backgroundColor;
    Color? borderColor;
    Color? textColor;
    Widget? trailingIcon;
    double scale = 1.0;
    bool shouldShake = false;

    if (isMatched) {
      // pastel yeşil arka plan ve kilit ikonu
      backgroundColor = Colors.green.shade50;
      borderColor = Colors.green.shade300;
      textColor = Colors.green.shade700;
      trailingIcon = Icon(
        Icons.lock,
        color: Colors.green.shade600,
        size: 18,
      );
    } else if (_showingFeedback && isSelected) {
      // feedback durumunda renk kontrolü
      if (_selectedLeftIndex != null && _selectedRightIndex != null) {
        String selectedWord = _leftColumn[_selectedLeftIndex!];
        String selectedMeaning = _rightColumn[_selectedRightIndex!];
        MatchingPair? correctPair = _pairs.firstWhere((pair) => pair.word == selectedWord);
        bool isCorrect = correctPair.meaning == selectedMeaning;
        
        if (isCorrect) {
          backgroundColor = Colors.green.shade50;
          borderColor = Colors.green.shade300;
          textColor = Colors.green.shade700;
        } else {
          // kırmızı titreşim efekti
          backgroundColor = Colors.red.shade50;
          borderColor = Colors.red.shade300;
          textColor = Colors.red.shade700;
          shouldShake = true;
        }
      }
    } else if (isSelected) {
      // seçili öğede outline + hafif scale
      backgroundColor = Theme.of(context).colorScheme.primary.withOpacity(0.1);
      borderColor = Theme.of(context).colorScheme.primary;
      textColor = Theme.of(context).colorScheme.primary;
      scale = 1.02;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      borderColor = Theme.of(context).colorScheme.outline.withOpacity(0.2);
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    Widget cardWidget = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 150),
      child: InkWell(
        onTap: isMatched ? null : () => _selectItem(isLeft, index),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72), // eşit yükseklik
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16), // 16px köşe radius
            border: Border.all(
              color: borderColor!,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: borderColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: textColor,
                    fontWeight: isSelected || isMatched ? FontWeight.w600 : FontWeight.w500,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                trailingIcon,
              ],
            ],
          ),
        ),
      ),
    );

    // yanlış eşleşmede titreşim animasyonu ekle
    if (shouldShake) {
      return AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              10 * _shakeAnimation.value * (1 - _shakeAnimation.value) * 
              ((_shakeAnimation.value * 10).floor() % 2 == 0 ? 1 : -1),
              0,
            ),
            child: cardWidget,
          );
        },
      );
    }

    return cardWidget;
  }
}

class MatchingPair {
  final int id;
  final String word;
  final String meaning;

  MatchingPair({
    required this.id,
    required this.word,
    required this.meaning,
  });
}

class MatchingQuizResultScreen extends StatelessWidget {
  final int correctAnswers;
  final int totalQuestions;
  final int earnedXp;
  final String category;

  const MatchingQuizResultScreen({
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
                        'Eşleştirme Tamamlandı!',
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
                        'Doğru Eşleşme',
                        '$correctAnswers/$totalQuestions',
                        Colors.green,
                        Icons.link,
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
                        builder: (context) => MatchingQuizScreen(category: category),
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
    return 'Daha İyi Olabilir';
  }

  String _getPerformanceEmoji(double percentage) {
    if (percentage >= 90) return '🏆';
    if (percentage >= 80) return '🎉';
    if (percentage >= 70) return '😊';
    if (percentage >= 60) return '👍';
    return '💪';
  }

  Color _getPerformanceColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}