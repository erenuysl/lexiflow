import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_service.dart';
import '../services/word_service.dart';
import '../widgets/guest_login_prompt.dart';
import '../utils/input_security.dart';
import 'deck_detail_screen.dart';

/// DecksScreen displays all personal word decks for authenticated users
/// Shows GuestLoginPrompt for guest users
class DecksScreen extends StatelessWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionService = Provider.of<SessionService>(context);
    final wordService = Provider.of<WordService>(context);

    // Show guest prompt if user is in guest mode
    if (sessionService.isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kişisel Desteler'),
        ),
        body: const GuestLoginPrompt(
          title: 'Giriş Yapın',
          message: 'Kişisel kelime destelerinizi görmek için giriş yapmanız gerekiyor.',
          icon: Icons.folder_special,
        ),
      );
    }

    // User must be logged in with Firebase
    final userId = sessionService.currentUser?.uid;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kişisel Desteler'),
        ),
        body: const Center(
          child: Text('Lütfen giriş yapın'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kişisel Desteler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateDeckDialog(context, wordService, userId),
            tooltip: 'Yeni Deste Oluştur',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: wordService.getDecksStream(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Hata: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final decks = snapshot.data ?? [];

          if (decks.isEmpty) {
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
                            Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.folder_special,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Henüz deste yok',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kendi kelime destelerinizi oluşturmaya başlayın',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: MediaQuery.of(context).textScaler.clamp(maxScaleFactor: 1.0),
                      ),
                      child: ElevatedButton.icon(
                      onPressed: () => _showCreateDeckDialog(context, wordService, userId),
                      icon: const Icon(Icons.add),
                      label: const Text('Deste Oluştur'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: decks.length,
            itemBuilder: (context, index) {
              final deck = decks[index];
              return _buildDeckCard(context, deck, wordService, userId);
            },
          );
        },
      ),
    );
  }

  Widget _buildDeckCard(
    BuildContext context,
    Map<String, dynamic> deck,
    WordService wordService,
    String userId,
  ) {
    final deckName = deck['name'] ?? 'Adsız Deste';
    final deckDescription = deck['description'] ?? '';
    final wordCount = deck['wordCount'] ?? 0;
    final deckId = deck['id'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeckDetailScreen(
                deckId: deckId,
                deckName: deckName,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder,
                  size: 32,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deckName,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (deckDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        deckDescription,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.book,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$wordCount kelime',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _showDeleteDeckDialog(
                  context,
                  wordService,
                  userId,
                  deckId,
                  deckName,
                ),
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateDeckDialog(
    BuildContext context,
    WordService wordService,
    String userId,
  ) {
    final nameController = SecureTextEditingController(
      validator: InputSecurity.validateDeckName,
      sanitizer: InputSecurity.sanitizeInput,
    );
    final descriptionController = SecureTextEditingController(
      validator: (text) => InputSecurity.validateInput(text, maxLength: 500),
      sanitizer: InputSecurity.sanitizeInput,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Deste Oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                labelText: 'Deste Adı',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
              ),
              decoration: const InputDecoration(
                labelText: 'Açıklama (İsteğe bağlı)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final description = descriptionController.text.trim();
              
              // Validate inputs
              final nameValidation = InputSecurity.validateDeckName(name);
              final descriptionValidation = InputSecurity.validateInput(description, maxLength: 500);
              
              if (!nameValidation.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deste adı hatası: ${nameValidation.errorMessage}')),
                );
                return;
              }
              
              if (!descriptionValidation.isValid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Açıklama hatası: ${descriptionValidation.errorMessage}')),
                );
                return;
              }

              try {
                await wordService.createDeck(
                  userId: userId,
                  name: InputSecurity.sanitizeInput(name),
                  description: InputSecurity.sanitizeInput(description),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deste oluşturuldu!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDeckDialog(
    BuildContext context,
    WordService wordService,
    String userId,
    String deckId,
    String deckName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desteyi Sil'),
        content: Text('$deckName destesini silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await wordService.deleteDeck(userId, deckId);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deste silindi')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
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
