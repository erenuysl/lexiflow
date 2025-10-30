import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_service.dart';
import '../services/word_service.dart';
import '../widgets/add_word_dialog.dart';

/// DeckDetailScreen displays all custom words in a deck
/// Uses StreamBuilder to listen to Firestore changes
class DeckDetailScreen extends StatelessWidget {
  final String deckId;
  final String deckName;

  const DeckDetailScreen({
    super.key,
    required this.deckId,
    required this.deckName,
  });

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context);
    final wordService = Provider.of<WordService>(context);
    final userId = sessionService.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(deckName)),
        body: const Center(child: Text('Lütfen giriş yapın')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(deckName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddWordDialog(context, wordService, userId),
            tooltip: 'Kelime Ekle',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: wordService.getCustomWordsStream(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Hata: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Geri Dön'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allWords = snapshot.data ?? [];
          // Filter words by deckId
          final deckWords =
              allWords
                  .where(
                    (word) =>
                        word['deckId'] == deckId || word['deckId'] == 'default',
                  )
                  .toList();

          if (deckWords.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            Theme.of(
                              context,
                            ).colorScheme.secondary.withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.book_outlined,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Henüz kelime yok',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bu desteye kelime eklemeye başlayın',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed:
                          () =>
                              _showAddWordDialog(context, wordService, userId),
                      icon: const Icon(Icons.add),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Kelime Ekle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: deckWords.length,
            itemBuilder: (context, index) {
              final word = deckWords[index];
              return _buildWordCard(context, word, wordService, userId);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWordDialog(context, wordService, userId),
        tooltip: 'Kelime Ekle',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildWordCard(
    BuildContext context,
    Map<String, dynamic> wordData,
    WordService wordService,
    String userId,
  ) {
    final word = wordData['word'] ?? '';
    final meaning = wordData['meaning'] ?? '';
    final example = wordData['example'] ?? '';
    final wordId = wordData['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        meaning,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed:
                      () => _showDeleteWordDialog(
                        context,
                        wordService,
                        userId,
                        wordId,
                        word,
                      ),
                  color: Colors.red,
                ),
              ],
            ),
            if (example.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        example,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddWordDialog(
    BuildContext context,
    WordService wordService,
    String userId,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AddWordDialog(
            wordService: wordService,
            userId: userId,
            deckId: deckId,
          ),
    );
  }

  void _showDeleteWordDialog(
    BuildContext context,
    WordService wordService,
    String userId,
    String wordId,
    String word,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kelimeyi Sil'),
            content: Text(
              '"$word" kelimesini silmek istediğinizden emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await wordService.deleteCustomWord(userId, wordId);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kelime silindi')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Hata: $e')));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
  }
}
