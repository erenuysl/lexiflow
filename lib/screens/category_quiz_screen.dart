import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../services/word_loader.dart';

class CategoryQuizScreen extends StatefulWidget {
  final String category;
  final String categoryName;
  final String categoryIcon;
  final Color? categoryColor;

  const CategoryQuizScreen({
    super.key,
    required this.category,
    required this.categoryName,
    required this.categoryIcon,
    this.categoryColor,
  });

  @override
  State<CategoryQuizScreen> createState() => _CategoryQuizScreenState();
}

class _CategoryQuizScreenState extends State<CategoryQuizScreen> {
  List<Word> categoryWords = [];
  bool isLoading = true;
  String searchQuery = '';
  List<Word> filteredWords = [];

  @override
  void initState() {
    super.initState();
    _loadCategoryWords();
  }

  Future<void> _loadCategoryWords() async {
    final words = await WordLoader.loadCategoryWords(widget.category);
    
    if (mounted) {
      setState(() {
        categoryWords = words;
        filteredWords = words;
        isLoading = false;
      });
    }
  }

  void _filterWords(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredWords = categoryWords;
      } else {
        filteredWords = categoryWords.where((word) {
          return word.word.toLowerCase().contains(query.toLowerCase()) ||
                 word.tr.toLowerCase().contains(query.toLowerCase()) ||
                 word.meaning.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _startQuiz() {
    if (categoryWords.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Quiz başlatmak için en az 4 kelime gerekli.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/quiz/start',
      arguments: {
        'categoryKey': widget.category,
        'categoryName': widget.categoryName,
        'categoryIcon': widget.categoryIcon,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    // Use category color for theming with soft opacity
    final categoryColor = widget.categoryColor ?? colorScheme.primary;
    final backgroundTint = categoryColor.withOpacity(0.1);
    final appBarTint = categoryColor.withOpacity(0.2);
    final buttonColor = categoryColor.withOpacity(0.8);

    return Hero(
      tag: 'category_${widget.category}',
      child: Scaffold(
        backgroundColor: backgroundTint,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            '${widget.categoryIcon} ${widget.categoryName}',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: appBarTint,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Bu kategoride ${categoryWords.length} kelime mevcut.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      body: Column(
        children: [
          // Modern Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              onChanged: _filterWords,
              decoration: InputDecoration(
                hintText: 'Kelime ara...',
                hintStyle: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: categoryColor.withOpacity(0.7),
                ),
                filled: true,
                fillColor: categoryColor.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: categoryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
          ),
          
          // Word List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredWords.isEmpty
                    ? _buildEmptyState(colorScheme, textTheme)
                    : _buildWordList(colorScheme, textTheme),
          ),
        ],
      ),
      
      // Fixed Bottom Quiz Button
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: categoryWords.length >= 4 ? _startQuiz : null,
          style: FilledButton.styleFrom(
            backgroundColor: categoryWords.length >= 4 
                ? buttonColor 
                : colorScheme.outline.withOpacity(0.3),
            foregroundColor: categoryWords.length >= 4 
                ? Colors.white 
                : colorScheme.onSurface.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: categoryWords.length >= 4 ? 2 : 0,
          ),
          icon: Icon(
            Icons.quiz_rounded,
            size: 20,
          ),
          label: Text(
            categoryWords.length >= 4 
                ? 'Bu Kategoriden Quiz Başlat'
                : 'Quiz için en az 4 kelime gerekli (${categoryWords.length}/4)',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                searchQuery.isEmpty ? Icons.library_books_outlined : Icons.search_off,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              searchQuery.isEmpty ? 'Bu kategoride kelime bulunamadı' : 'Arama sonucu bulunamadı',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isEmpty 
                  ? 'Bu kategori henüz kelime içermiyor.'
                  : 'Farklı bir arama terimi deneyin.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (searchQuery.isNotEmpty) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () => _filterWords(''),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Tüm kelimeleri göster'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWordList(ColorScheme colorScheme, TextTheme textTheme) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filteredWords.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final word = filteredWords[index];
        return _buildWordCard(word, colorScheme, textTheme);
      },
    );
  }

  Widget _buildWordCard(Word word, ColorScheme colorScheme, TextTheme textTheme) {
    return Card(
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          word.word,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            word.tr,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        children: [
          const SizedBox(height: 8),
          if (word.meaning.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Anlamı',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    word.meaning,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (word.exampleSentence.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.format_quote,
                        size: 16,
                        color: colorScheme.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Örnek Cümle',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    word.exampleSentence,
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurface.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}