import 'package:flutter/material.dart';
import 'package:lexiflow/models/category_theme.dart';
import 'package:lexiflow/screens/multiple_choice_quiz_screen.dart';
import 'package:lexiflow/screens/matching_quiz_screen.dart';
import 'package:lexiflow/screens/fill_blanks_quiz_screen.dart';

class QuizTypeSelectScreen extends StatelessWidget {
  final String category;

  const QuizTypeSelectScreen({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    // kategori temasını al, yoksa varsayılan kullan
    final theme = categoryThemes[category] ?? 
      const CategoryTheme(
        emoji: '🎯',
        color: Colors.blueAccent,
        title: 'Quiz',
        description: 'Hazırsan başlayalım!',
      );

    return Scaffold(
      appBar: AppBar(
        title: Text('${theme.title} Quiz Seçenekleri'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
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
              const SizedBox(height: 20),
              
              // başlık
              Text(
                'Quiz Türünü Seçin',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Hangi tür quiz oynamak istiyorsunuz?',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // quiz türü butonları
              _buildQuizTypeButton(
                context,
                title: 'Çoktan Seçmeli',
                description: 'Doğru cevabı seçenekler arasından bul',
                icon: Icons.quiz_outlined,
                color: Colors.blue,
                onTap: () => _navigateToQuiz(context, 'multiple_choice'),
              ),
              
              const SizedBox(height: 16),
              
              _buildQuizTypeButton(
                context,
                title: 'Eşleştirme',
                description: 'Kelimeleri anlamlarıyla eşleştir',
                icon: Icons.compare_arrows,
                color: Colors.green,
                onTap: () => _navigateToQuiz(context, 'matching'),
              ),
              
              const SizedBox(height: 16),
              
              _buildQuizTypeButton(
                context,
                title: 'Boşluk Doldurma',
                description: 'Eksik kelimeleri tamamla',
                icon: Icons.edit_outlined,
                color: Colors.orange,
                onTap: () => _navigateToQuiz(context, 'fill_blanks'),
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizTypeButton(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // ikon container
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              
              const SizedBox(width: 20),
              
              // başlık ve açıklama
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
              
              // ok ikonu
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToQuiz(BuildContext context, String quizType) {
    Widget targetScreen;
    
    switch (quizType) {
      case 'multiple_choice':
        targetScreen = MultipleChoiceQuizScreen(category: category);
        break;
      case 'matching':
        targetScreen = MatchingQuizScreen(category: category);
        break;
      case 'fill_blanks':
        targetScreen = FillBlanksQuizScreen(category: category);
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => targetScreen,
      ),
    );
  }
}