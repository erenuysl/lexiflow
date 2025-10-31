import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/word_loader.dart';

class QuizCenterScreen extends StatefulWidget {
  const QuizCenterScreen({super.key});

  @override
  State<QuizCenterScreen> createState() => _QuizCenterScreenState();
}

class _QuizCenterScreenState extends State<QuizCenterScreen> {
  Map<String, int> categoryWordCounts = {};
  bool isLoading = true;

  // Category data with Turkish names, emojis, and colors
  static const Map<String, Map<String, dynamic>> categories = {
    'biology': {
      'name': 'Biyoloji', 
      'icon': '🧬',
      'color': Color(0xFF4CAF50), // Green
      'lightColor': Color(0xFFE8F5E8),
    },
    'technology': {
      'name': 'Teknoloji', 
      'icon': '⚙️',
      'color': Color(0xFF607D8B), // Blue Grey
      'lightColor': Color(0xFFECEFF1),
    },
    'history': {
      'name': 'Tarih', 
      'icon': '📜',
      'color': Color(0xFF8D6E63), // Brown
      'lightColor': Color(0xFFF3E5AB),
    },
    'geography': {
      'name': 'Coğrafya', 
      'icon': '🌍',
      'color': Color(0xFF00BCD4), // Cyan
      'lightColor': Color(0xFFE0F7FA),
    },
    'psychology': {
      'name': 'Psikoloji', 
      'icon': '🧠',
      'color': Color(0xFF9C27B0), // Purple
      'lightColor': Color(0xFFF3E5F5),
    },
    'business': {
      'name': 'İş Dünyası', 
      'icon': '💼',
      'color': Color(0xFF795548), // Brown
      'lightColor': Color(0xFFEFEBE9),
    },
    'communication': {
      'name': 'İletişim', 
      'icon': '💬',
      'color': Color(0xFF2196F3), // Blue
      'lightColor': Color(0xFFE3F2FD),
    },
    'everyday_english': {
      'name': 'Günlük İngilizce', 
      'icon': '🗣️',
      'color': Color(0xFFFF9800), // Orange
      'lightColor': Color(0xFFFFF3E0),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadCategoryWordCounts();
  }

  Future<void> _loadCategoryWordCounts() async {
    final Map<String, int> counts = {};
    
    for (String category in categories.keys) {
      counts[category] = await WordLoader.getCategoryWordCount(category);
    }
    
    if (mounted) {
      setState(() {
        categoryWordCounts = counts;
        isLoading = false;
      });
    }
  }

  void _startCategoryQuiz(String categoryKey) {
    final categoryData = categories[categoryKey]!;
    Navigator.pushNamed(
      context,
      '/quiz/start',
      arguments: {
        'categoryKey': categoryKey,
        'categoryName': categoryData['name'],
        'categoryIcon': categoryData['icon'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Kelime Pratikleri',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // General Quiz Card
            _buildGeneralQuizCard(colorScheme, textTheme),
            const SizedBox(height: 32),
            
            // Categories Section Title
            Text(
              'Kategorilere Göre Quizler',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            
            // Categories Grid
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              _buildCategoriesGrid(colorScheme, textTheme),
            ],
          ),
        ),
    );
  }

  Widget _buildGeneralQuizCard(ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      elevation: 6,
      shadowColor: colorScheme.shadow.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/quiz/general');
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer,
                colorScheme.surfaceTint.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.book_solid,
                  size: 40,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'İngilizcede En Fazla Kullanılan 1000 Kelime',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Genel İngilizce kelimelerle rastgele quiz oluştur.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(ColorScheme colorScheme, TextTheme textTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive grid columns
        int crossAxisCount = 2;
        if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 24,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final categoryKey = categories.keys.elementAt(index);
              final categoryData = categories[categoryKey]!;
              final wordCount = categoryWordCounts[categoryKey] ?? 0;

              return _buildCategoryCard(
                context,
                categoryKey,
                categoryData,
                wordCount,
                colorScheme,
                textTheme,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    String categoryKey,
    Map<String, dynamic> categoryData,
    int wordCount,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final categoryColor = categoryData['color'] as Color;
    
    // Strengthen gradients with more vibrant colors
    List<Color> gradientColors;
    switch (categoryKey) {
      case 'biology':
        gradientColors = [Colors.greenAccent.withOpacity(0.4), Colors.green.withOpacity(0.2)];
        break;
      case 'history':
        gradientColors = [Colors.orangeAccent.withOpacity(0.4), Colors.orange.withOpacity(0.2)];
        break;
      case 'geography':
        gradientColors = [Colors.lightBlueAccent.withOpacity(0.4), Colors.lightBlue.withOpacity(0.2)];
        break;
      case 'technology':
        gradientColors = [Colors.blueGrey.withOpacity(0.4), Colors.blueGrey.withOpacity(0.2)];
        break;
      case 'psychology':
        gradientColors = [Colors.purpleAccent.withOpacity(0.4), Colors.purple.withOpacity(0.2)];
        break;
      case 'business':
        gradientColors = [Colors.brown.withOpacity(0.4), Colors.brown.withOpacity(0.2)];
        break;
      case 'communication':
        gradientColors = [Colors.blueAccent.withOpacity(0.4), Colors.blue.withOpacity(0.2)];
        break;
      case 'everyday_english':
        gradientColors = [Colors.orangeAccent.withOpacity(0.4), Colors.orange.withOpacity(0.2)];
        break;
      default:
        gradientColors = [categoryColor.withOpacity(0.4), categoryColor.withOpacity(0.2)];
    }
    
    return Hero(
      tag: 'category_$categoryKey',
      child: Card(
        elevation: 8,
        shadowColor: Theme.of(context).shadowColor.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/quiz/category/$categoryKey',
              arguments: {
                'category': categoryKey,
                'categoryName': categoryData['name'],
                'categoryIcon': categoryData['icon'],
                'color': categoryColor,
              },
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: AnimatedScale(
            scale: 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  categoryData['icon']!,
                  style: const TextStyle(fontSize: 36),
                ),
                Text(
                  categoryData['name']!,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: categoryColor.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$wordCount kelime',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Quiz Başlat'),
                  style: FilledButton.styleFrom(
                    backgroundColor: categoryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    minimumSize: const Size(double.infinity, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _startCategoryQuiz(categoryKey),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}