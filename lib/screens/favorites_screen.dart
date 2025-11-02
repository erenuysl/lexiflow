import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word_model.dart';
import '../services/ad_service.dart';
import '../services/session_service.dart';
import '../services/user_service.dart';
import '../services/word_service.dart';
import '../services/learned_words_service.dart';
import '../utils/input_security.dart';
import '../widgets/lexiflow_toast.dart';
import 'add_word_screen.dart';
import 'word_detail_screen.dart';
import 'favorites_quiz_screen.dart';
import 'learned_quiz_screen.dart';

String _buildWordHeroTag(Word word) {
  final normalized = word.word.trim();
  if (normalized.isNotEmpty) {
    return 'word_$normalized';
  }

  final hiveKey = word.key;
  if (hiveKey != null) {
    final keyString = hiveKey.toString().trim();
    if (keyString.isNotEmpty) {
      return 'word_$keyString';
    }
  }

  final createdAt = word.createdAt;
  if (createdAt != null) {
    return 'word_unknown_${createdAt.millisecondsSinceEpoch}';
  }

  return 'word_${word.hashCode}';
}

class FavoritesScreen extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final AdService adService;

  const FavoritesScreen({
    super.key,
    required this.wordService,
    required this.userService,
    required this.adService,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

// Specialized Word Card for Learned Words
class _LearnedWordCard extends StatefulWidget {
  final Word word;
  final String uid;
  final WordService wordService;
  final Function(int)? onRemove;
  final int index;

  const _LearnedWordCard({
    required this.word,
    required this.uid,
    required this.wordService,
    this.onRemove,
    required this.index,
  });

  @override
  State<_LearnedWordCard> createState() => _LearnedWordCardState();
}

class _LearnedWordCardState extends State<_LearnedWordCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _removeController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _removeSlideAnimation;
  late final String _wordHeroTag;

  @override
  void initState() {
    super.initState();

    _wordHeroTag = _buildWordHeroTag(widget.word);

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _removeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _removeController, curve: Curves.easeInOut),
    );

    _removeSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0),
    ).animate(
      CurvedAnimation(parent: _removeController, curve: Curves.easeInOut),
    );

    // Start slide-in animation
    _slideController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    _removeController.dispose();
    super.dispose();
  }

  void _animateIconTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
  }

  Future<void> _handleUnlearn() async {
    _animateIconTap();

    // Start remove animation
    await _removeController.forward();

    // Call the remove callback
    if (widget.onRemove != null) {
      widget.onRemove!(widget.index);
    }
  }

  void _openWordDetail() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                WordDetailScreen(word: widget.word),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(
                Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic)),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _removeSlideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _openWordDetail,
                  child: Semantics(
                    label:
                        'Öğrenilen kelime: ${widget.word.word}, Türkçe: ${widget.word.tr}, Anlamı: ${widget.word.meaning}',
                    hint: 'Kelime detaylarını görmek için dokunun',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.withOpacity(0.05),
                            Colors.green.withOpacity(0.02),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Unique Hero tag to avoid collisions even if word is empty
                                  Hero(
                                    tag: _wordHeroTag,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Text(
                                        widget.word.word,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (widget.word.tr.isNotEmpty) ...[
                                    Text(
                                      widget.word.tr,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  if (widget.word.meaning.isNotEmpty) ...[
                                    Text(
                                      widget.word.meaning,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: _handleUnlearn,
                                  child: Semantics(
                                    label:
                                        '${widget.word.word} kelimesini öğrenilenlerden çıkar',
                                    hint:
                                        'Bu kelimeyi öğrenilenler listesinden kaldırmak için dokunun',
                                    button: true,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  String _searchQuery = '';
  late final SecureTextEditingController _searchController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController = SecureTextEditingController(
      validator: InputSecurity.validateSearchQuery,
      sanitizer: InputSecurity.sanitizeInput,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, IconData icon) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAddWordDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddWordScreen(wordService: widget.wordService),
      ),
    );
  }

  Future<void> _handleQuizRequest(
    List<Word> favorites, {
    bool isLearnedWords = false,
  }) async {
    if (favorites.length < 4) {
      _showSnackBar(
        isLearnedWords
            ? 'En az 4 öğrenilen kelime gerekiyor.'
            : 'En az 4 favori kelime gerekiyor.',
        Icons.info_outline,
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                isLearnedWords
                    ? LearnedQuizScreen(
                      wordService: widget.wordService,
                      userService: widget.userService,
                      adService: widget.adService,
                      learnedWords: favorites,
                    )
                    : FavoritesQuizScreen(
                      wordService: widget.wordService,
                      userService: widget.userService,
                      adService: widget.adService,
                      favoriteWords: favorites,
                    ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionService>(context);
    final isGuest = session.isGuest || session.isAnonymous;

    if (isGuest) {
      return Column(
        children: [
          // Başlık alanı
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Kelimelerim',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: _buildGuestView()),
        ],
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Başlık ve TabBar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kelimelerim',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.favorite, color: Colors.pink),
                      text: "Favoriler",
                    ),
                    Tab(
                      icon: Icon(Icons.check_circle, color: Colors.green),
                      text: "Öğrenilenler",
                    ),
                  ],
                ),
              ],
            ),
          ),
          // İçerik
          Expanded(
            child: SafeArea(
              bottom: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.3, 0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: TabBarView(
                  key: ValueKey(_tabController.index),
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _FavoritesList(
                      wordService: widget.wordService,
                      userService: widget.userService,
                      adService: widget.adService,
                      onQuizRequest: _handleQuizRequest,
                      searchController: _searchController,
                      searchQuery: _searchQuery,
                      onSearchChanged:
                          (value) => setState(() => _searchQuery = value),
                    ),
                    _LearnedWordsList(
                      wordService: widget.wordService,
                      userService: widget.userService,
                      adService: widget.adService,
                      onQuizRequest:
                          (words) =>
                              _handleQuizRequest(words, isLearnedWords: true),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Favoriler Sadece Üyeler İçin',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Favori kelimelerinizi kaydetmek için lütfen giriş yapın',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Favorites List Widget
class _FavoritesList extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final AdService adService;
  final Function(List<Word>) onQuizRequest;
  final TextEditingController searchController;
  final String searchQuery;
  final Function(String) onSearchChanged;

  const _FavoritesList({
    required this.wordService,
    required this.userService,
    required this.adService,
    required this.onQuizRequest,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  State<_FavoritesList> createState() => _FavoritesListState();
}

class _FavoritesListState extends State<_FavoritesList> {
  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionService>(context, listen: false);
    final uid = session.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Set<String>>(
      stream: widget.wordService.favoritesKeysStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final keys = snapshot.data ?? <String>{};
        final favorites = List<Word>.from(
          widget.wordService.mapFavoriteKeysToWords(keys),
        );

        // Apply search filter
        final filteredFavorites =
            widget.searchQuery.isEmpty
                ? favorites
                : favorites.where((w) {
                  final query = widget.searchQuery.toLowerCase();
                  return w.word.toLowerCase().contains(query) ||
                      w.meaning.toLowerCase().contains(query);
                }).toList();

        if (favorites.isEmpty) {
          return _buildEmptyState(
            icon: Icons.favorite_border,
            title: 'Henüz Favori Kelime Yok',
            subtitle:
                'Kelime kartlarındaki kalp ikonuna tıklayarak favori kelimeler ekleyebilirsin',
            color: Colors.pink,
          );
        }

        return Column(
          children: [
            // Search bar
            if (favorites.length > 3)
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: widget.searchController,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Kelime ara...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        widget.searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                widget.searchController.clear();
                                widget.onSearchChanged('');
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: widget.onSearchChanged,
                ),
              ),

            // Quiz Banner
            _buildQuizBanner(favorites, false),

            // Words Count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.favorite, size: 16, color: Colors.pink),
                  const SizedBox(width: 8),
                  Text(
                    '${filteredFavorites.length} kelime',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Words List
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                cacheExtent: 500,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredFavorites.length,
                itemBuilder: (context, index) {
                  final word = filteredFavorites[index];
                  return _WordCard(
                    word: word,
                    uid: uid,
                    wordService: widget.wordService,
                    isLearned: false,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuizBanner(List<Word> words, bool isLearnedWords) {
    final canStartQuiz = words.length >= 4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canStartQuiz ? () => widget.onQuizRequest(words) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    canStartQuiz
                        ? [Colors.pink, Colors.pink.shade300]
                        : [Colors.grey.shade300, Colors.grey.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.quiz, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canStartQuiz
                            ? 'Favorilerle Quiz Başlat'
                            : 'Quiz için 4 kelime gerekli',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        canStartQuiz
                            ? '${words.length} kelime ile quiz çöz'
                            : 'Daha ${4 - words.length} kelime ekle',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  canStartQuiz ? Icons.play_arrow_rounded : Icons.lock_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: color.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Learned Words List Widget
class _LearnedWordsList extends StatefulWidget {
  final WordService wordService;
  final UserService userService;
  final AdService adService;
  final Function(List<Word>) onQuizRequest;

  const _LearnedWordsList({
    required this.wordService,
    required this.userService,
    required this.adService,
    required this.onQuizRequest,
  });

  @override
  State<_LearnedWordsList> createState() => _LearnedWordsListState();
}

class _LearnedWordsListState extends State<_LearnedWordsList>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  String _searchQuery = '';
  List<Word> _allLearnedWords = [];
  List<Word> _filteredWords = [];
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final LearnedWordsService _learnedWordsService = LearnedWordsService();

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        final searchText = _searchController.text.trim();

        final validation = InputSecurity.validateSearchQuery(searchText);
        if (!validation.isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Arama hatası: ${validation.errorMessage}')),
          );
          _searchController.clear();
          return;
        }

        setState(() {
          _searchQuery = InputSecurity.sanitizeInput(searchText).toLowerCase();
          _filterWords();
        });
      }
    });
  }

  void _filterWords() {
    if (_searchQuery.isEmpty) {
      _filteredWords = List.from(_allLearnedWords);
    } else {
      _filteredWords =
          _allLearnedWords.where((word) {
            return word.word.toLowerCase().contains(_searchQuery) ||
                word.meaning.toLowerCase().contains(_searchQuery) ||
                (word.tr.isNotEmpty &&
                    word.tr.toLowerCase().contains(_searchQuery));
          }).toList();
    }
  }

  Future<void> _removeWordFromLearned(Word word, int index) async {
    final session = Provider.of<SessionService>(context, listen: false);
    final uid = session.currentUser?.uid;

    if (uid == null) return;

    // Optimistic UI - remove immediately
    setState(() {
      _filteredWords.removeAt(index);
      _allLearnedWords.removeWhere((w) => w.word == word.word);
    });

    // Animate removal
    _listKey.currentState?.removeItem(
      index,
      (context, animation) =>
          _buildWordCard(word, uid, animation, isRemoving: true),
      duration: const Duration(milliseconds: 400),
    );

    try {
      // Remove from learned words service
      final success = await _learnedWordsService.unmarkWordAsLearned(
        uid,
        word.word,
        word: word,
      );

      if (success && mounted) {
        showLexiflowToast(
          context,
          ToastType.success,
          'Kelime öğrenilenlerden kaldırıldı.',
        );
      } else if (mounted) {
        // Revert optimistic UI on failure
        setState(() {
          _allLearnedWords.insert(index, word);
          _filterWords();
        });

        showLexiflowToast(
          context,
          ToastType.error,
          'Bir hata oluştu. Tekrar deneyin.',
        );
      }
    } catch (e) {
      if (mounted) {
        // Revert optimistic UI on error
        setState(() {
          _allLearnedWords.insert(index, word);
          _filterWords();
        });

        showLexiflowToast(
          context,
          ToastType.error,
          'Bir hata oluştu. Tekrar deneyin.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionService>(context, listen: false);
    final uid = session.currentUser?.uid;

    if (uid == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('learned_words')
              .orderBy('learnedAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Bir hata oluştu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Lütfen tekrar deneyin',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Yenile'),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final entries = <MapEntry<String, Map<String, dynamic>>>[];
        final canonicalKeys = <String>{};

        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final wordField = (data['word'] ?? '').toString().trim();
          final wordIdField = (data['wordId'] ?? '').toString().trim();
          final canonical =
              wordField.isNotEmpty
                  ? wordField
                  : (wordIdField.isNotEmpty ? wordIdField : doc.id.trim());

          if (canonical.isEmpty) {
            continue;
          }

          entries.add(MapEntry(canonical, data));
          canonicalKeys.add(canonical);
        }

        final mappedWords = widget.wordService.mapLearnedKeysToWords(
          canonicalKeys,
        );
        final mappedByKey = <String, Word>{
          for (final word in mappedWords) word.word.trim().toLowerCase(): word,
        };

        _allLearnedWords =
            entries.map((entry) {
              final canonical = entry.key;
              final data = entry.value;
              final lowerKey = canonical.trim().toLowerCase();
              final mapped = mappedByKey[lowerKey];
              if (mapped != null) {
                return mapped;
              }

              final example = (data['example'] ?? '').toString();
              final exampleSentence =
                  (data['exampleSentence'] ?? example).toString();
              final category = (data['category'] ?? '').toString();
              final learnedAt = data['learnedAt'];

              DateTime? createdAt;
              if (learnedAt is Timestamp) {
                createdAt = learnedAt.toDate();
              } else if (learnedAt is DateTime) {
                createdAt = learnedAt;
              }

              return Word(
                word: canonical,
                meaning: (data['meaning'] ?? '').toString(),
                example: example,
                tr: (data['tr'] ?? '').toString(),
                exampleSentence: exampleSentence,
                isCustom: (data['isCustom'] ?? false) == true,
                category: category.isNotEmpty ? category : null,
                createdAt: createdAt,
              );
            }).toList();

        _filterWords();

        if (_allLearnedWords.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            title: 'Henüz Öğrenilen Kelime Yok',
            subtitle:
                'Quiz çözerek doğru cevapladığın kelimeler burada görünecek',
            color: Colors.green,
          );
        }

        // Filter out favorites for quiz (learned-only quiz)
        final learnedOnlyWords =
            _allLearnedWords.where((word) => !word.isFavorite).toList();

        return Column(
          children: [
            // Search Bar
            _buildSearchBar(),

            // Quiz Banner for Learned Words
            _buildLearnedQuizBanner(learnedOnlyWords),

            // Words Count and Results
            _buildWordsCount(),

            // Words List or No Results
            Expanded(
              child:
                  _filteredWords.isEmpty && _searchQuery.isNotEmpty
                      ? _buildNoResultsState()
                      : AnimatedList(
                        key: _listKey,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        initialItemCount: _filteredWords.length,
                        itemBuilder: (context, index, animation) {
                          if (index >= _filteredWords.length)
                            return const SizedBox.shrink();
                          final word = _filteredWords[index];
                          return _buildWordCard(word, uid, animation);
                        },
                      ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: _searchAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _searchFocusNode.hasFocus
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                          context,
                        ).colorScheme.outline.withOpacity(0.3),
                width: _searchFocusNode.hasFocus ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Öğrenilen kelimelerde ara...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.6),
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchFocusNode.unfocus();
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onTap: () {
                _searchAnimationController.forward();
              },
              onEditingComplete: () {
                _searchFocusNode.unfocus();
                _searchAnimationController.reverse();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildWordsCount() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(
            _searchQuery.isEmpty
                ? '${_allLearnedWords.length} öğrenilen kelime'
                : '${_filteredWords.length} sonuç (${_allLearnedWords.length} toplam)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                _searchFocusNode.unfocus();
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Temizle'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Sonuç Bulunamadı',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '"$_searchQuery" için eşleşen kelime bulunamadı',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                _searchController.clear();
                _searchFocusNode.unfocus();
              },
              child: const Text('Aramayı Temizle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard(
    Word word,
    String uid,
    Animation<double> animation, {
    bool isRemoving = false,
  }) {
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
      ),
      child: FadeTransition(
        opacity: animation,
        child: _LearnedWordCard(
          word: word,
          uid: uid,
          wordService: widget.wordService,
          onRemove:
              isRemoving
                  ? null
                  : (index) => _removeWordFromLearned(word, index),
          index: _filteredWords.indexOf(word),
        ),
      ),
    );
  }

  Widget _buildLearnedQuizBanner(List<Word> words) {
    final canStartQuiz = words.length >= 4;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canStartQuiz ? () => widget.onQuizRequest(words) : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    canStartQuiz
                        ? [Colors.green, Colors.green.shade300]
                        : [Colors.grey.shade300, Colors.grey.shade400],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.quiz, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        canStartQuiz
                            ? '🎯 Quiz başlat (öğrenilen kelimelerden)'
                            : 'Quiz için 4 kelime gerekli',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        canStartQuiz
                            ? '${words.length} öğrenilen kelime ile quiz çöz'
                            : 'Daha ${4 - words.length} kelime öğren',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  canStartQuiz ? Icons.play_arrow_rounded : Icons.lock_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: color.withOpacity(0.3)),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Shared Word Card Widget
class _WordCard extends StatefulWidget {
  final Word word;
  final String uid;
  final WordService wordService;
  final bool isLearned;

  const _WordCard({
    required this.word,
    required this.uid,
    required this.wordService,
    required this.isLearned,
  });

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    // Start slide-in animation
    _slideController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _animateIconTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _slideController,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient:
                  widget.isLearned
                      ? LinearGradient(
                        colors: [
                          Colors.green.withOpacity(0.05),
                          Colors.green.withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : LinearGradient(
                        colors: [
                          Colors.pink.withOpacity(0.05),
                          Colors.pink.withOpacity(0.02),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.word.word,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.word.tr,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        if (widget.word.meaning.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.word.meaning,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!widget.isLearned)
                    StreamBuilder<Set<String>>(
                      stream: widget.wordService.favoritesKeysStream(
                        widget.uid,
                      ),
                      builder: (context, snapshot) {
                        final favoriteKeys = snapshot.data ?? <String>{};
                        final isFavorite = favoriteKeys.contains(
                          widget.word.word,
                        );

                        return ScaleTransition(
                          scale: _scaleAnimation,
                          child: IconButton(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              _animateIconTap();
                              try {
                                await widget.wordService
                                    .toggleFavoriteFirestore(
                                      widget.word,
                                      widget.uid,
                                    );
                                if (context.mounted) {
                                  showLexiflowToast(
                                    context,
                                    ToastType.success,
                                    isFavorite
                                        ? 'Favorilerden çıkarıldı'
                                        : 'Favorilere eklendi',
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  showLexiflowToast(
                                    context,
                                    ToastType.error,
                                    'Bir hata oluştu',
                                  );
                                }
                              }
                            },
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                  scale: animation,
                                  child: child,
                                );
                              },
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey(isFavorite),
                                color: isFavorite ? Colors.red : Colors.grey,
                              ),
                            ),
                          ),
                        );
                      },
                    )
                  else
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 24,
                        ),
                      ),
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
