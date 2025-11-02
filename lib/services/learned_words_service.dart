// lib/services/learned_words_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/word_model.dart';
import '../utils/logger.dart';
import 'sync_manager.dart';
import 'firestore_schema_v2.dart';
import 'offline_storage_manager.dart';
import 'connectivity_service.dart';
import 'session_service.dart'; // Added for refreshStats
import '../providers/profile_stats_provider.dart';
import '../di/locator.dart';
import 'word_service.dart';
import 'category_progress_service.dart';

class LearnedWordRecord {
  final String docId;
  final String word;
  final String normalizedWord;
  final String category;

  const LearnedWordRecord({
    required this.docId,
    required this.word,
    required this.normalizedWord,
    required this.category,
  });
}

class LearnedWordsService {
  static final LearnedWordsService _instance = LearnedWordsService._internal();
  factory LearnedWordsService() => _instance;
  LearnedWordsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _learnedWordsBoxName = 'learned_words';

  // Cache for learned words to avoid repeated Firestore calls
  final Map<String, Set<String>> _learnedWordsCache = {};

  LearnedWordRecord? _recordFromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return null;
    }

    final docId = doc.id.trim();
    final wordField = (data['word'] ?? '').toString().trim();
    final wordIdField = (data['wordId'] ?? '').toString().trim();
    final canonical =
        wordField.isNotEmpty
            ? wordField
            : (wordIdField.isNotEmpty ? wordIdField : docId);

    if (canonical.isEmpty) {
      return null;
    }

    final category = (data['category'] ?? '').toString().trim();

    return LearnedWordRecord(
      docId: docId,
      word: canonical,
      normalizedWord: canonical.toLowerCase(),
      category: category,
    );
  }

  List<LearnedWordRecord> _recordsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final records = <LearnedWordRecord>[];
    for (final doc in snapshot.docs) {
      final record = _recordFromDocument(doc);
      if (record != null) {
        records.add(record);
      }
    }
    return records;
  }

  Future<List<LearnedWordRecord>> _getOfflineLearnedWordRecords(
    String userId,
  ) async {
    final box = Hive.box<String>(_learnedWordsBoxName);
    final records = <LearnedWordRecord>[];

    for (final key in box.keys) {
      final rawKey = key.toString();
      if (!rawKey.startsWith('${userId}_')) {
        continue;
      }

      final docId = rawKey.substring('${userId}_'.length);
      final cacheKey = 'learned_words_${userId}_$docId';
      final cache = await OfflineStorageManager().loadWordCache(cacheKey);

      final cachedWord = (cache?['word'] ?? '').toString().trim();
      final canonical = cachedWord.isNotEmpty ? cachedWord : docId;
      if (canonical.isEmpty) {
        continue;
      }

      final category = (cache?['category'] ?? '').toString().trim();

      records.add(
        LearnedWordRecord(
          docId: docId,
          word: canonical,
          normalizedWord: canonical.toLowerCase(),
          category: category,
        ),
      );
    }

    _learnedWordsCache[userId] = records.map((r) => r.docId).toSet();
    return records;
  }

  String _safeDocId(Word word) {
    final raw = (word.word).toLowerCase().trim();
    if (raw.isNotEmpty) {
      return raw;
    }

    String? fallback;

    final createdAt = word.createdAt;
    if (createdAt != null) {
      fallback = 'unknown_${createdAt.millisecondsSinceEpoch}';
    }

    if (fallback == null) {
      final dynamic hiveKey = word.key;
      if (hiveKey != null) {
        final keyString = hiveKey.toString().trim();
        if (keyString.isNotEmpty) {
          fallback = 'unknown_$keyString';
        }
      }
    }

    if (fallback == null) {
      final example = word.example.trim();
      if (example.isNotEmpty) {
        fallback = 'unknown_${example.hashCode}';
      }
    }

    if (fallback == null) {
      final meaning = word.meaning.trim();
      if (meaning.isNotEmpty) {
        fallback = 'unknown_${meaning.hashCode}';
      }
    }

    fallback ??= 'unknown_${DateTime.now().millisecondsSinceEpoch}';

    if (kDebugMode) {
      print('[Firestore] Safe doc id: $fallback');
    }

    return fallback;
  }

  String _normalizeDocId(String? raw) => (raw ?? '').toLowerCase().trim();

  String _resolveDocId(String? raw, {Word? word}) {
    final normalized = _normalizeDocId(raw);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    if (word != null) {
      return _safeDocId(word);
    }
    return '';
  }

  /// Initialize the service and open Hive box
  Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen(_learnedWordsBoxName)) {
        await Hive.openBox<String>(_learnedWordsBoxName);
      }
      Logger.i('LearnedWordsService initialized', 'LearnedWordsService');
    } catch (e) {
      Logger.e(
        'Failed to initialize LearnedWordsService',
        e,
        null,
        'LearnedWordsService',
      );
    }
  }

  /// Backfill empty category fields in learned_words for a user
  /// Queries up to 300 docs with empty category and tries to resolve category
  /// from local assets via WordService, then writes back with merge.
  Future<void> backfillLearnedCategories(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final query =
        await firestore
            .collection('users')
            .doc(userId)
            .collection('learned_words')
            .where('category', isEqualTo: '')
            .limit(300)
            .get();

    if (kDebugMode) {
      print(
        '[BACKFILL] Found ${query.docs.length} empty-category learned words.',
      );
    }

    final wordService = locator<WordService>();

    for (final doc in query.docs) {
      final data = doc.data();
      final wordId = (data['wordId'] ?? doc.id).toString();

      // Resolve Word using WordService's local database
      final resolved = wordService.mapLearnedKeysToWords({wordId});
      final word = resolved.isNotEmpty ? resolved.first : null;
      final newCategory = (word?.category ?? '').toLowerCase();

      if (newCategory.isNotEmpty) {
        await doc.reference.set({
          'category': newCategory,
        }, SetOptions(merge: true));
        if (kDebugMode) {
          print('[BACKFILL] $wordId -> $newCategory');
        }
      } else {
        if (kDebugMode) {
          print('[BACKFILL] skipped $wordId (no category in assets)');
        }
      }
    }

    if (kDebugMode) {
      print('[BACKFILL] Completed.');
    }
  }

  /// Otomatik backfill tetikleyici: kullanıcı açılışında eksik kategorileri kontrol eder
  /// Eğer users/{uid}/learned_words içinde category alanı boş olan kayıt varsa
  /// backfillLearnedCategories(userId) çağrılır. Aksi halde atlanır.
  Future<void> autoBackfillIfNeeded(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final query =
        await firestore
            .collection('users')
            .doc(userId)
            .collection('learned_words')
            .where('category', isEqualTo: '')
            .limit(1)
            .get();

    if (query.docs.isNotEmpty) {
      if (kDebugMode) {
        print(
          '[AUTO_BACKFILL] Detected uncategorized learned words. Starting backfill...',
        );
      }
      await backfillLearnedCategories(userId);
    } else {
      if (kDebugMode) {
        print('[AUTO_BACKFILL] No missing categories detected. Skipping.');
      }
    }
  }

  /// Check if a word is learned by a user
  Future<bool> isWordLearned(String userId, String wordId, {Word? word}) async {
    try {
      final docId = _resolveDocId(wordId, word: word);
      if (docId.isEmpty) {
        if (kDebugMode) {
          print(
            '[Firestore] Skipping learned check due to empty doc id (uid=$userId)',
          );
        }
        return false;
      }

      final cache = _learnedWordsCache[userId];
      if (cache != null) {
        if (cache.contains(docId)) {
          return true;
        }

        final legacyId = _normalizeDocId(wordId);
        if (legacyId.isNotEmpty && cache.contains(legacyId)) {
          return true;
        }

        if (cache.contains(wordId)) {
          return true;
        }

        if (word != null) {
          final normalizedWord = _normalizeDocId(word.word);
          if (normalizedWord.isNotEmpty && cache.contains(normalizedWord)) {
            return true;
          }
        }
      }

      // Check if we're online
      final isOnline = await ConnectivityService().checkConnectivity();

      if (isOnline) {
        // Check Firestore when online
        final doc =
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('learned_words')
                .doc(docId)
                .get();

        final isLearned = doc.exists;

        // Update cache
        _learnedWordsCache[userId] ??= <String>{};
        if (isLearned) {
          _learnedWordsCache[userId]!.add(docId);
        }

        // Also store in offline storage for future offline access
        if (isLearned) {
          await OfflineStorageManager().saveWordCache(
            'learned_words_${userId}_$docId',
            {'learnedAt': DateTime.now().toIso8601String()},
          );
        }

        return isLearned;
      } else {
        // Check offline storage when offline
        final offlineData = await OfflineStorageManager().loadWordCache(
          'learned_words_${userId}_$docId',
        );
        final isLearned = offlineData != null;

        // Update cache
        _learnedWordsCache[userId] ??= <String>{};
        if (isLearned) {
          _learnedWordsCache[userId]!.add(docId);
        }

        return isLearned;
      }
    } catch (e) {
      Logger.e(
        'Error checking if word is learned',
        e,
        null,
        'LearnedWordsService',
      );

      // Final fallback to Hive storage
      final box = Hive.box<String>(_learnedWordsBoxName);
      final docId = _resolveDocId(wordId, word: word);
      final localKey =
          docId.isNotEmpty ? '${userId}_$docId' : '${userId}_$wordId';
      return box.containsKey(localKey);
    }
  }

  /// Mark a word as learned
  Future<bool> markWordAsLearned(String userId, Word word) async {
    final safeWord = Word(
      word: word.word.trim(),
      meaning:
          word.meaning.trim().isNotEmpty
              ? word.meaning.trim()
              : 'No meaning provided',
      example:
          word.example.trim().isNotEmpty
              ? word.example.trim()
              : 'No example available',
      tr: word.tr.trim().isNotEmpty ? word.tr.trim() : '',
      exampleSentence:
          word.exampleSentence.trim().isNotEmpty
              ? word.exampleSentence.trim()
              : (word.example.trim().isNotEmpty
                  ? word.example.trim()
                  : 'No example available'),
      isCustom: word.isCustom,
      category:
          word.category?.trim().isNotEmpty == true
              ? word.category!.trim()
              : (word.category ?? ''),
      createdAt: word.createdAt,
    );

    final docId = _resolveDocId(safeWord.word, word: safeWord);
    if (docId.isEmpty) {
      if (kDebugMode) {
        print(
          '[Firestore] Failed to compute safe doc id for learned word (uid=$userId)',
        );
      }
      return false;
    }

    final normalizedCategory = (safeWord.category ?? '').trim().toLowerCase();

    final insertPayload = FirestoreSchemaV2.createLearnedWord(
      wordId: docId,
      category: normalizedCategory,
      word: safeWord.word,
      meaning: safeWord.meaning,
      tr: safeWord.tr,
      example: safeWord.example,
      exampleSentence: safeWord.exampleSentence,
      isCustom: safeWord.isCustom,
      includeCreatedAt: true,
    );

    final updatePayload = FirestoreSchemaV2.createLearnedWord(
      wordId: docId,
      category: normalizedCategory.isNotEmpty ? normalizedCategory : null,
      word: safeWord.word,
      meaning: safeWord.meaning,
      tr: safeWord.tr,
      example: safeWord.example,
      exampleSentence: safeWord.exampleSentence,
      isCustom: safeWord.isCustom,
      includeCreatedAt: false,
    );

    try {
      _learnedWordsCache[userId] ??= <String>{};
      _learnedWordsCache[userId]!.add(docId);
      await OfflineStorageManager()
          .saveWordCache('learned_words_${userId}_$docId', {
            'learnedAt': DateTime.now().toIso8601String(),
            'word': safeWord.word,
            'meaning': safeWord.meaning,
            'example': safeWord.example,
            'tr': safeWord.tr,
            'category': normalizedCategory,
          });
      final box = Hive.box<String>(_learnedWordsBoxName);
      final localKey = '${userId}_$docId';
      await box.put(localKey, DateTime.now().toIso8601String());

      final isOnline = await ConnectivityService().checkConnectivity();
      if (isOnline) {
        final docRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('learned_words')
            .doc(docId);

        await _firestore.runTransaction((tx) async {
          final snap = await tx.get(docRef);
          if (!snap.exists) {
            tx.set(docRef, insertPayload, SetOptions(merge: true));
            if (kDebugMode) {
              print(
                '[LearnedWordsService] inserted new: ${safeWord.word} (${safeWord.category})',
              );
            }

            final statsRef = _firestore.collection('users').doc(userId);
            final leaderboardRef = _firestore
                .collection('leaderboard_stats')
                .doc(userId);
            tx.update(statsRef, {
              'learnedWordsCount': FieldValue.increment(1),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            tx.update(leaderboardRef, {
              'learnedWordsCount': FieldValue.increment(1),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          } else {
            tx.set(docRef, updatePayload, SetOptions(merge: true));
            if (kDebugMode) {
              print(
                '[LearnedWordsService] refreshed learned entry for ${safeWord.word}',
              );
            }
          }
        });

        try {
          final sessionService = SessionService();
          await sessionService.refreshStats();
          Logger.i(
            '?Y"S SessionService stats refreshed after word learned',
            'LearnedWordsService',
          );
        } catch (e) {
          Logger.w(
            'Failed to refresh SessionService stats',
            'LearnedWordsService',
          );
        }

        try {
          final profileStatsProvider = ProfileStatsProvider();
          await profileStatsProvider.incrementStreakIfNewDay();
          Logger.i(
            '[STREAK] Streak increment attempted after word learned',
            'LearnedWordsService',
          );
        } catch (e) {
          Logger.e(
            '[STREAK] Failed to increment streak after word learned',
            e,
            null,
            'LearnedWordsService',
          );
        }

        Logger.i(
          'Word marked as learned successfully: $docId',
          'LearnedWordsService',
        );

        if (normalizedCategory.isNotEmpty) {
          try {
            await locator<CategoryProgressService>().invalidateCacheForCategory(
              normalizedCategory,
            );
            if (kDebugMode) {
              print(
                '[CategoryProgressCache] invalidated for $normalizedCategory',
              );
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                '[WARN] Failed to invalidate cache for $normalizedCategory: $e',
              );
            }
          }
        }
      } else {
        await _queueLearnedWordForSync(userId, safeWord, docId);
        Logger.i(
          'Word marked as learned offline, queued for sync: $docId',
          'LearnedWordsService',
        );
      }

      return true;
    } catch (e) {
      Logger.e('Error marking word as learned', e, null, 'LearnedWordsService');
      await _queueLearnedWordForSync(userId, safeWord, docId);
      return true;
    }
  }

  /// Remove invalid learned words where the 'word' field is empty
  Future<void> cleanupInvalidLearnedWords(String userId) async {
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('learned_words');

    final snapshot = await col.get();
    int removed = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      // Only consider documents that explicitly have a 'word' field AND it's empty
      if (data.containsKey('word')) {
        final wordText = (data['word'] ?? '').toString().trim();
        if (wordText.isEmpty) {
          await doc.reference.delete();
          removed++;
        }
      }
    }

    if (kDebugMode) {
      print('[CLEANUP] Removed $removed invalid learned words.');
    }
  }

  /// Queue learned word operation for sync when online
  Future<void> _queueLearnedWordForSync(
    String userId,
    Word word,
    String docId,
  ) async {
    try {
      // Prepare Firestore operations for offline sync (V2 schema)
      final learnedWordData = FirestoreSchemaV2.createLearnedWord(
        wordId: docId,
        category: word.category,
        word: word.word,
        meaning: word.meaning,
        tr: word.tr,
        example: word.example,
        exampleSentence: word.exampleSentence,
        isCustom: word.isCustom,
      );

      // Queue learned word creation
      await SyncManager().addOperation(
        path: FirestoreSchemaV2.getLearnedWordsPath(userId, docId),
        type: SyncOperationType.create,
        data: learnedWordData,
      );

      // Queue stats update with standardized field name
      await SyncManager().addOperation(
        path: 'users/$userId',
        type: SyncOperationType.update,
        data: {
          'learnedWordsCount': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      );

      // Queue leaderboard update with standardized field name
      await SyncManager().addOperation(
        path: 'leaderboard_stats/$userId',
        type: SyncOperationType.update,
        data: {
          'learnedWordsCount': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      );

      Logger.i(
        'Learned word queued for sync: ${word.word}',
        'LearnedWordsService',
      );
    } catch (e) {
      Logger.e(
        'Error queuing learned word for sync',
        e,
        null,
        'LearnedWordsService',
      );
    }
  }

  Future<List<LearnedWordRecord>> getLearnedWordRecords(String userId) async {
    try {
      final isOnline = await ConnectivityService().checkConnectivity();
      if (isOnline) {
        final snapshot =
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('learned_words')
                .orderBy('learnedAt', descending: true)
                .get();

        final records = _recordsFromSnapshot(snapshot);
        _learnedWordsCache[userId] = records.map((r) => r.docId).toSet();
        return records;
      } else {
        return _getOfflineLearnedWordRecords(userId);
      }
    } catch (e) {
      Logger.e(
        'Error getting learned word records',
        e,
        null,
        'LearnedWordsService',
      );
      return _getOfflineLearnedWordRecords(userId);
    }
  }

  /// Get all learned words for a user (canonical word strings)
  Future<List<String>> getLearnedWords(String userId) async {
    final records = await getLearnedWordRecords(userId);
    return records.map((record) => record.word).toList();
  }

  Stream<List<LearnedWordRecord>> watchLearnedWordRecords(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learned_words')
        .snapshots()
        .map((snapshot) {
          final records = _recordsFromSnapshot(snapshot);
          _learnedWordsCache[userId] = records.map((r) => r.docId).toSet();
          return records;
        });
  }

  /// Get learned words count for a user
  Future<int> getLearnedWordsCount(String userId) async {
    try {
      // Check if we're online
      final isOnline = await ConnectivityService().checkConnectivity();

      if (isOnline) {
        final snapshot =
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('learned_words')
                .get();

        return snapshot.docs.length;
      } else {
        // Get count from offline storage when offline
        final box = Hive.box<String>(_learnedWordsBoxName);
        int count = 0;

        for (final key in box.keys) {
          if (key.toString().startsWith('${userId}_')) {
            count++;
          }
        }

        return count;
      }
    } catch (e) {
      Logger.e(
        'Error getting learned words count',
        e,
        null,
        'LearnedWordsService',
      );

      // Final fallback to Hive storage
      final box = Hive.box<String>(_learnedWordsBoxName);
      int count = 0;

      for (final key in box.keys) {
        if (key.toString().startsWith('${userId}_')) {
          count++;
        }
      }

      return count;
    }
  }

  /// Stream of learned words for reactive UI
  Stream<Set<String>> getLearnedWordsStream(String userId) {
    return watchLearnedWordRecords(
      userId,
    ).map((records) => records.map((record) => record.word).toSet());
  }

  /// Clear cache for a user (useful for logout)
  void clearCache(String userId) {
    _learnedWordsCache.remove(userId);
  }

  /// Clear all caches
  void clearAllCaches() {
    _learnedWordsCache.clear();
  }

  /// Sync pending learned words when connectivity is restored
  Future<void> syncPendingLearnedWords(String userId) async {
    try {
      final box = Hive.box<String>(_learnedWordsBoxName);
      final pendingWords = <String>[];

      // Find local words that might not be synced
      for (final key in box.keys) {
        if (key.toString().startsWith('${userId}_')) {
          final wordId = key.toString().substring('${userId}_'.length);

          // Check if it exists in Firestore
          final exists = await isWordLearned(userId, wordId);
          if (!exists) {
            pendingWords.add(wordId);
          }
        }
      }

      Logger.i(
        'Found ${pendingWords.length} pending learned words to sync',
        'LearnedWordsService',
      );

      // Note: Actual sync will be handled by SyncManager
      // This method is mainly for monitoring and cleanup
    } catch (e) {
      Logger.e(
        'Error syncing pending learned words',
        e,
        null,
        'LearnedWordsService',
      );
    }
  }

  /// Unmark a word as learned (remove from learned words)
  Future<bool> unmarkWordAsLearned(
    String userId,
    String wordId, {
    Word? word,
  }) async {
    try {
      final docId = _resolveDocId(wordId, word: word);
      if (docId.isEmpty) {
        if (kDebugMode) {
          print(
            '[Firestore] Skipping unlearn due to empty doc id (uid=$userId)',
          );
        }
        return false;
      }

      // Check if word is actually learned
      if (!await isWordLearned(userId, docId, word: word)) {
        Logger.i(
          'Word is not learned, cannot unmark: $docId',
          'LearnedWordsService',
        );
        return false; // Not learned, no action needed
      }

      // Update local cache immediately (optimistic UI)
      _learnedWordsCache[userId]?.remove(docId);

      // Remove from offline storage immediately
      await OfflineStorageManager().removeWordCache(
        'learned_words_${userId}_$docId',
      );

      // Also remove from Hive as backup
      final box = Hive.box<String>(_learnedWordsBoxName);
      final localKey = '${userId}_$docId';
      await box.delete(localKey);

      // Check if we're online
      final isOnline = await ConnectivityService().checkConnectivity();

      if (isOnline) {
        // Update Firestore in transaction to ensure consistency
        await _firestore.runTransaction((transaction) async {
          // References
          final learnedWordRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('learned_words')
              .doc(docId);

          final statsRef = _firestore.collection('users').doc(userId);

          final leaderboardRef = _firestore
              .collection('leaderboard_stats')
              .doc(userId);

          // Check if word is actually learned (idempotency check in transaction)
          final existingDoc = await transaction.get(learnedWordRef);
          if (!existingDoc.exists) {
            Logger.i(
              '[LEARNED] Word not in subcollection, skipping: $docId (uid=$userId)',
              'LearnedWordsService',
            );
            return; // Do nothing - idempotent behavior
          }

          // Remove learned word
          transaction.delete(learnedWordRef);

          // Decrement stats with standardized field name
          transaction.update(statsRef, {
            'learnedWordsCount': FieldValue.increment(-1),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Update leaderboard stats with standardized field name
          transaction.update(leaderboardRef, {
            'learnedWordsCount': FieldValue.increment(-1),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          Logger.i(
            '[LEARNED] -1 -> learnedWordsCount after remove (uid=$userId, wordId=$docId)',
            'LearnedWordsService',
          );
        });

        // Trigger SessionService refresh for real-time UI updates
        try {
          final sessionService = SessionService();
          await sessionService.refreshStats();
          Logger.i(
            '📊 SessionService stats refreshed after word unmarked',
            'LearnedWordsService',
          );
        } catch (e) {
          Logger.w(
            'Failed to refresh SessionService stats',
            'LearnedWordsService',
          );
        }

        Logger.i(
          'Word unmarked as learned successfully: $docId',
          'LearnedWordsService',
        );
      } else {
        // Queue the operation for later sync when offline
        await _queueUnlearnedWordForSync(userId, docId);
        Logger.i(
          'Word unmarked as learned offline, queued for sync: $docId',
          'LearnedWordsService',
        );
      }

      return true;
    } catch (e) {
      Logger.e(
        'Error unmarking word as learned',
        e,
        null,
        'LearnedWordsService',
      );

      // Queue the operation for later sync
      final fallbackDocId = _resolveDocId(wordId, word: word);
      if (fallbackDocId.isNotEmpty) {
        await _queueUnlearnedWordForSync(userId, fallbackDocId);
      }
      return true; // Still return true for UI feedback
    }
  }

  /// Queue unlearned word operation for sync when online
  Future<void> _queueUnlearnedWordForSync(String userId, String wordId) async {
    try {
      // Queue learned word deletion
      await SyncManager().addOperation(
        path: 'users/$userId/learned_words/$wordId',
        type: SyncOperationType.delete,
        data: {},
      );

      // Queue stats update with standardized field name
      await SyncManager().addOperation(
        path: 'users/$userId',
        type: SyncOperationType.update,
        data: {
          'learnedWordsCount': FieldValue.increment(-1),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      );

      // Queue leaderboard update with standardized field name
      await SyncManager().addOperation(
        path: 'leaderboard_stats/$userId',
        type: SyncOperationType.update,
        data: {
          'learnedWordsCount': FieldValue.increment(-1),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      );

      Logger.i(
        'Unlearned word queued for sync: $wordId',
        'LearnedWordsService',
      );
    } catch (e) {
      Logger.e(
        'Error queuing unlearned word for sync',
        e,
        null,
        'LearnedWordsService',
      );
    }
  }
}
