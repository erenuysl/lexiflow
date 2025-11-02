import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class QuizResultsScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final int earnedXp;
  final bool leveledUp;
  final int currentLevel;
  final VoidCallback onPlayAgain;
  final VoidCallback onBackToFavorites;
  final String? quizType;

  const QuizResultsScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.earnedXp,
    required this.leveledUp,
    required this.currentLevel,
    required this.onPlayAgain,
    required this.onBackToFavorites,
    this.quizType,
  });

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animationController.forward();
    });

    if (widget.score == widget.totalQuestions || widget.leveledUp) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _performanceMessage() {
    final percentage = (widget.score / widget.totalQuestions * 100).round();
    if (percentage == 100) return 'Mükemmel!';
    if (percentage >= 80) return 'Harika!';
    if (percentage >= 60) return 'İyi iş!';
    if (percentage >= 40) return 'Daha iyi olacak!';
    return 'Tekrar deneyelim!';
  }

  Color _performanceColor() {
    final percentage = (widget.score / widget.totalQuestions * 100).round();
    if (percentage >= 80) return const Color(0xFF4ECDC4);
    if (percentage >= 60) return const Color(0xFFFFB347);
    return const Color(0xFFFF416C);
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.score / widget.totalQuestions * 100).round();
    final perfColor = _performanceColor();
    final isLearnedQuiz = widget.quizType == 'learned';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Stack(
                  children: [
                    // Arka plan gradyanı - öğrenilen quiz için yeşil, diğerleri için varsayılan
                    Container(
                      height: constraints.maxHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isLearnedQuiz 
                              ? [const Color(0xFF4ADE80), const Color(0xFF16A34A)] // Green gradient for learned quiz
                              : [const Color(0xFF06D6A0), const Color(0xFF4ECDC4)], // Default gradient
                        ),
                      ),
                    ),

                    // Konfeti
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        emissionFrequency: 0.06,
                        numberOfParticles: 40,
                        gravity: 0.12,
                        colors: const [
                          Colors.white,
                          Colors.tealAccent,
                          Colors.lightGreenAccent,
                        ],
                      ),
                    ),

                    // İçerik
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),
                            // Başlık ikonu
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: CircleAvatar(
                                radius: 38,
                                backgroundColor: Colors.white24,
                                child: Icon(
                                  isLearnedQuiz ? Icons.school : Icons.emoji_events,
                                  color: Colors.white,
                                  size: 44,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isLearnedQuiz ? 'Öğrenilenler Quiz Tamamlandı!' : 'Quiz Tamamlandı!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isLearnedQuiz 
                                  ? 'Tebrikler! Öğrendiğin kelimeleri başarıyla hatırladın 🎯'
                                  : _performanceMessage(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 3 mini istatistik (tek satır)
                            Row(
                              children: [
                                Expanded(
                                  child: _miniStat(
                                    icon: Icons.check_circle,
                                    title: 'Doğru',
                                    value: '${widget.score}/${widget.totalQuestions}',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _miniStat(
                                    icon: isLearnedQuiz ? Icons.percent : Icons.bolt,
                                    title: isLearnedQuiz ? 'Başarı' : 'XP',
                                    value: isLearnedQuiz ? '%$percentage' : '+${widget.earnedXp}',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _miniStat(
                                    icon: isLearnedQuiz 
                                        ? Icons.quiz 
                                        : (widget.leveledUp ? Icons.celebration : Icons.military_tech),
                                    title: isLearnedQuiz ? 'Soru' : 'Seviye',
                                    value: isLearnedQuiz 
                                        ? '${widget.totalQuestions}' 
                                        : 'Lv ${widget.currentLevel}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _progressBar(percentage, perfColor),
                            // bottom padding için alan bırak
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                child: OutlinedButton.icon(
                  onPressed: widget.onPlayAgain,
                  icon: const Icon(Icons.replay),
                  label: const Text('Tekrar Oyna'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Icons.home),
                  label: const Text('Ana Menü'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressBar(int percentage, Color color) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1000),
      tween: Tween(begin: 0.0, end: (percentage / 100).clamp(0.0, 1.0)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final v = value.clamp(0.0, 1.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Başarı Oranı',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${(v * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
