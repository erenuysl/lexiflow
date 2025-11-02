import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import '../models/word_model.dart';
import '../services/word_loader.dart';
import '../services/local_word_cache_service.dart';
import '../models/category_theme.dart';
import 'quiz_type_select_screen.dart';
import 'package:lexiflow/services/category_progress_service.dart';
import 'package:lexiflow/di/locator.dart';
import 'package:lexiflow/services/session_service.dart';

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
        filteredWords =
            categoryWords.where((word) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizTypeSelectScreen(category: widget.category),
      ),
    );
  }

  void _showAddWordDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final englishController = TextEditingController();
    final turkishController = TextEditingController();
    final exampleController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Yeni Kelime Ekle',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // English word field
                    TextFormField(
                      controller: englishController,
                      decoration: InputDecoration(
                        labelText: 'İngilizce Kelime',
                        hintText: 'Örnek: beautiful',
                        prefixIcon: const Icon(Icons.language),
                        filled: true,
                        fillColor: colorScheme.secondaryContainer.withOpacity(
                          0.1,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'İngilizce kelime gerekli';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Turkish meaning field
                    TextFormField(
                      controller: turkishController,
                      decoration: InputDecoration(
                        labelText: 'Türkçe Anlam',
                        hintText: 'Örnek: güzel',
                        prefixIcon: const Icon(Icons.translate),
                        filled: true,
                        fillColor: colorScheme.secondaryContainer.withOpacity(
                          0.1,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Türkçe anlam gerekli';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Example sentence field (optional)
                    TextFormField(
                      controller: exampleController,
                      decoration: InputDecoration(
                        labelText: 'Örnek Cümle (İsteğe bağlı)',
                        hintText: 'Örnek: She is very beautiful.',
                        prefixIcon: const Icon(Icons.chat_bubble_outline),
                        filled: true,
                        fillColor: colorScheme.secondaryContainer.withOpacity(
                          0.1,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Vazgeç'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              await _addCustomWord(
                                englishController.text.trim(),
                                turkishController.text.trim(),
                                exampleController.text.trim(),
                              );
                              Navigator.pop(context);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                          ),
                          child: const Text('Kaydet'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _addCustomWord(
    String englishWord,
    String turkishMeaning,
    String example,
  ) async {
    try {
      // Check for duplicates
      final existingWord = categoryWords.firstWhere(
        (w) => w.word.toLowerCase() == englishWord.toLowerCase(),
        orElse: () => Word(word: '', meaning: '', example: ''),
      );

      if (existingWord.word.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bu kelime zaten mevcut!'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }

      // Create new custom word
      final newWord = Word(
        word: englishWord,
        tr: turkishMeaning,
        meaning: turkishMeaning,
        example: example.isEmpty ? '' : example,
        category: widget.category,
        isCustom: true,
        createdAt: DateTime.now(),
      );

      // Add to local storage
      await LocalWordCacheService().addCustomWord(widget.category, newWord);

      // Refresh the word list
      await _loadCategoryWords();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kelime başarıyla eklendi ✅'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // kategori temasını al, yoksa varsayılan kullan
    final theme =
        categoryThemes[widget.category] ??
        const CategoryTheme(
          emoji: '🎯',
          color: Colors.blueAccent,
          title: 'Quiz',
          description: 'Hazırsan başlayalım!',
        );

    // Use category color for theming with soft opacity
    final categoryColor = widget.categoryColor ?? colorScheme.primary;
    final backgroundTint = categoryColor.withOpacity(0.1);
    final appBarTint = categoryColor.withOpacity(0.2);
    final buttonColor = categoryColor.withOpacity(0.8);
    // Progress header dependencies
    final userId = locator<SessionService>().currentUser?.uid;
    final cps = locator<CategoryProgressService>();
    final categoryKey = widget.category;

    return Hero(
      tag: 'category_${widget.category}',
      child: Scaffold(
        backgroundColor: backgroundTint,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            '${theme.emoji} ${theme.title}',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          backgroundColor: appBarTint,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              icon: Icon(Icons.add, color: categoryColor),
              onPressed: () => _showAddWordDialog(context),
              tooltip: 'Yeni Kelime Ekle',
            ),
          ],
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
            // Category progress summary header
            // Hidden when loading, when there are no words, or when percent is 0.
            if (!isLoading && categoryWords.isNotEmpty)
              StreamBuilder<double>(
                stream:
                    userId != null
                        ? cps.watchProgressPercent(userId, categoryKey)
                        : null,
                builder: (context, snapshot) {
                  // First-load: tiny shimmer placeholder (indeterminate progress)
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: null,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(
                              context,
                            ).colorScheme.surfaceVariant.withOpacity(0.6),
                          ),
                          semanticsLabel: 'Yükleniyor',
                        ),
                      ),
                    );
                  }

                  final percent = snapshot.data ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: percent / 100),
                        duration: const Duration(milliseconds: 500),
                        builder: (context, value, _) {
                          return LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade800,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getCategoryColor(categoryKey),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

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
                    borderSide: BorderSide(color: categoryColor, width: 2),
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
              child:
                  isLoading
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
              backgroundColor:
                  categoryWords.length >= 4
                      ? buttonColor
                      : colorScheme.outline.withOpacity(0.3),
              foregroundColor:
                  categoryWords.length >= 4
                      ? Colors.white
                      : colorScheme.onSurface.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: categoryWords.length >= 4 ? 2 : 0,
            ),
            icon: Icon(Icons.quiz_rounded, size: 20),
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
                searchQuery.isEmpty
                    ? Icons.library_books_outlined
                    : Icons.search_off,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              searchQuery.isEmpty
                  ? 'Bu kategoride kelime bulunamadı'
                  : 'Arama sonucu bulunamadı',
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

  Widget _buildWordCard(
    Word word,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Card(
      elevation: 2,
      shadowColor: colorScheme.shadow.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // özel kelimeler için farklı border
        side:
            word.isCustom
                ? BorderSide(color: Colors.orange.withOpacity(0.6), width: 2)
                : BorderSide.none,
      ),
      child: GestureDetector(
        onLongPress: word.isCustom ? () => _showDeleteDialog(word) : null,
        child: Container(
          decoration:
              word.isCustom
                  ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.05),
                        Colors.orange.withOpacity(0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  )
                  : null,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    word.word,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (word.isCustom) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Özel',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
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
        ),
      ),
    );
  }

  void _showDeleteDialog(Word word) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 12),
              Text(
                'Kelimeyi Sil',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu özel kelimeyi silmek istediğinizden emin misiniz?',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.word,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.tr,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'İptal',
                style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteCustomWord(word);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCustomWord(Word word) async {
    try {
      // LocalWordCacheService'den kelimeyi sil
      await LocalWordCacheService().deleteCustomWord(
        widget.category,
        word.word,
      );

      // Kelime listesini yenile
      await _loadCategoryWords();

      // Başarı mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${word.word} kelimesi silindi ✅'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      // Hata mesajı göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kelime silinirken hata oluştu: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

// Kategorilere özel renk eşlemesi (QuizCenter ile tutarlı görünüm için)
Color _getCategoryColor(String category) {
  switch (category) {
    case 'biology':
      return Colors.greenAccent;
    case 'technology':
      return Colors.blueAccent;
    case 'history':
      return Colors.brown;
    case 'geography':
      return Colors.lightBlueAccent;
    case 'psychology':
      return Colors.purpleAccent;
    case 'business':
      return Colors.orangeAccent;
    case 'communication':
      return Colors.tealAccent;
    case 'everyday_english':
      return Colors.amberAccent;
    default:
      return Colors.grey;
  }
}
