// lib/services/learned_words_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/word_model.dart';
import '../utils/logger.dart';
import 'sync_manager.dart';
import 'offline_storage_manager.dart';
import 'connectivity_service.dart';
import 'session_service.dart'; // Added for refreshStats

class LearnedWordsService {
  static final LearnedWordsService _instance = LearnedWordsService._internal();
  factory LearnedWordsService() => _instance;
  LearnedWordsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _learnedWordsBoxName = 'learned_words';
  
  // Cache for learned words to avoid repeated Firestore calls
  final Map<String, Set<String>> _learnedWordsCache = {};
  
  /// Initialize the service and open Hive box
  Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen(_learnedWordsBoxName)) {
        await Hive.openBox<String>(_learnedWordsBoxName);
      }
      Logger.i('LearnedWordsService initialized', 'LearnedWordsService');
    } catch (e) {
      Logger.e('Failed to initialize LearnedWordsService', e, null, 'LearnedWordsService');
    }
  }

  /// Check if a word is learned by a user
  Future<bool> isWordLearned(String userId, String wordId) async {
    try {
      // Check cache first
      if (_learnedWordsCache[userId]?.contains(wordId) == true) {
        return true;
      }

      // Check if we're online
      final isOnline = await ConnectivityService().checkConnectivity();
      
      if (isOnline) {
        // Check Firestore when online
        final doc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('learned_words')
            .doc(wordId)
            .get();

        final isLearned = doc.exists;
        
        // Update cache
        _learnedWordsCache[userId] ??= <String>{};
        if (isLearned) {
          _learnedWordsCache[userId]!.add(wordId);
        }

        // Also store in offline storage for future offline access
        if (isLearned) {
          await OfflineStorageManager().saveWordCache(
            'learned_words_${userId}_$wordId',
            {'learnedAt': DateTime.now().toIso8601String()},
          );
        }

        return isLearned;
      } else {
        // Check offline storage when offline
        final offlineData = await OfflineStorageManager().loadWordCache('learned_words_${userId}_$wordId');
        final isLearned = offlineData != null;
        
        // Update cache
        _learnedWordsCache[userId] ??= <String>{};
        if (isLearned) {
          _learnedWordsCache[userId]!.add(wordId);
        }
        
        return isLearned;
      }
    } catch (e) {
      Logger.e('Error checking if word is learned', e, null, 'LearnedWordsService');
      
      // Final fallback to Hive storage
      final box = Hive.box<String>(_learnedWordsBoxName);
      final localKey = '${userId}_$wordId';
      return box.containsKey(localKey);
    }
  }

  /// Mark a word as learned
  Future<bool> markWordAsLearned(String userId, Word word) async {
    try {
      final wordId = word.word;
      
      // Check if already learned to prevent duplicates
      if (await isWordLearned(userId, wordId)) {
        Logger.i('Word already marked as learned: $wordId', 'LearnedWordsService');
        return false; // Already learned, no action needed
      }

      // Update local cache immediately (optimistic UI)
      _learnedWordsCache[userId] ??= <String>{};
      _learnedWordsCache[userId]!.add(wordId);

      // Store in offline storage immediately for offline support
      await OfflineStorageManager().saveWordCache(
        'learned_words_${userId}_$wordId',
        {
          'learnedAt': DateTime.now().toIso8601String(),
          'word': wordId,
          'meaning': word.meaning,
          'example': word.example,
        },
      );

      // Also store in Hive as backup
      final box = Hive.box<String>(_learnedWordsBoxName);
      final localKey = '${userId}_$wordId';
      await box.put(localKey, DateTime.now().toIso8601String());

      // Check if we're online
      final isOnline = await ConnectivityService().checkConnectivity();
      
      if (isOnline) {
        // Prepare Firestore operations
        final learnedWordData = {
          'learnedAt': FieldValue.serverTimestamp(),
          'word': wordId,
          'meaning': word.meaning,
          'example': word.example,
        };

        // Update Firestore in transaction to ensure consistency
        await _firestore.runTransaction((transaction) async {
          // References
          final learnedWordRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('learned_words')
              .doc(wordId);
              
          final statsRef = _firestore
              .collection('users')
              .doc(userId);
              
          final leaderboardRef = _firestore
              .collection('leaderboard_stats')
              .doc(userId);

          // Check if word is already learned (idempotency check in transaction)
          final existingDoc = await transaction.get(learnedWordRef);
          if (existingDoc.exists) {
            Logger.i('[LEARNED] Word already exists in subcollection, skipping: $wordId (uid=$userId)', 'LearnedWordsService');
            return; // Do nothing - idempotent behavior
          }

          // Add learned word
          transaction.set(learnedWordRef, learnedWordData);

          // Increment stats with standardized field name
          transaction.update(statsRef, {
            'learnedWordsCount': FieldValue.increment(1),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Update leaderboard stats with standardized field name
          transaction.update(leaderboardRef, {
            'learnedWordsCount': FieldValue.increment(1),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          Logger.i('[LEARNED] +1 -> learnedWordsCount after add (uid=$userId, wordId=$wordId)', 'LearnedWordsService');
        });

        // Trigger SessionService refresh for real-time UI updates
        try {
          final sessionService = SessionService();
          await sessionService.refreshStats();
          Logger.i('📊 SessionService stats refreshed after word learned', 'LearnedWordsService');
        } catch (e) {
          Logger.w('Failed to refresh SessionService stats', 'LearnedWordsService');
        }

        Logger.i('Word marked as learned successfully: $wordId', 'LearnedWordsService');
      } else {
        // Queue the operation for later sync when offline
        await _queueLearnedWordForSync(userId, word);
        Logger.i('Word marked as learned offline, queued for sync: $wordId', 'LearnedWordsService');
      }

      return true;

    } catch (e) {
      Logger.e('Error marking word as learned', e, null, 'LearnedWordsService');
      
      // Queue the operation for later sync
      await _queueLearnedWordForSync(userId, word);
      return true; // Still return true for UI feedback
    }
  }

  /// Queue learned word operation for sync when online
  Future<void> _queueLearnedWordForSync(String userId, Word word) async {
    try {
      final learnedWordData = {
        'learnedAt': FieldValue.serverTimestamp(),
        'word': word.word,
        'meaning': word.meaning,
        'example': word.example,
      };

      // Queue learned word creation
      await SyncManager().addOperation(
        path: 'users/$userId/learned_words/${word.word}',
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

      Logger.i('Learned word queued for sync: ${word.word}', 'LearnedWordsService');
    } catch (e) {
      Logger.e('Error queuing learned word for sync', e, null, 'LearnedWordsService');
    }
  }

  /// Get all learned words for a user
  Future<List<String>> getLearnedWords(String userId) async {
    try {
      // Check if we're online
      final isOnline = await ConnectivityService().checkConnectivity();
      
      if (isOnline) {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('learned_words')
            .orderBy('learnedAt', descending: true)
            .get();

        final learnedWords = snapshot.docs.map((doc) => doc.id).toList();
        
        // Update cache
        _learnedWordsCache[userId] = learnedWords.toSet();
        
        // Store in offline storage for future offline access
        for (final wordId in learnedWords) {
          await OfflineStorageManager().saveWordCache(
            'learned_words_${userId}_$wordId',
            {'learnedAt': DateTime.now().toIso8601String()},
          );
        }
        
        return learnedWords;
      } else {
        // Get from offline storage when offline
        final offlineWords = <String>[];
        
        // Check Hive box for offline words
        final box = Hive.box<String>(_learnedWordsBoxName);
        for (final key in box.keys) {
          if (key.toString().startsWith('${userId}_')) {
            final wordId = key.toString().substring('${userId}_'.length);
            offlineWords.add(wordId);
          }
        }
        
        // Update cache
        _learnedWordsCache[userId] = offlineWords.toSet();
        
        return offlineWords;
      }
    } catch (e) {
      Logger.e('Error getting learned words', e, null, 'LearnedWordsService');
      
      // Final fallback to Hive storage
      final box = Hive.box<String>(_learnedWordsBoxName);
      final localWords = <String>[];
      
      for (final key in box.keys) {
        if (key.toString().startsWith('${userId}_')) {
          final wordId = key.toString().substring('${userId}_'.length);
          localWords.add(wordId);
        }
      }
      
      return localWords;
    }
  }

  /// Get learned words count for a user
  Future<int> getLearnedWordsCount(String userId) async {
    try {
      // Check if we're online
      final isOnline = await ConnectivityService().checkConnectivity();
      
      if (isOnline) {
        final snapshot = await _firestore
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
      Logger.e('Error getting learned words count', e, null, 'LearnedWordsService');
      
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
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('learned_words')
        .snapshots()
        .map((snapshot) {
      final learnedWords = snapshot.docs.map((doc) => doc.id).toSet();
      
      // Update cache
      _learnedWordsCache[userId] = learnedWords;
      
      return learnedWords;
    });
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

      Logger.i('Found ${pendingWords.length} pending learned words to sync', 'LearnedWordsService');
      
      // Note: Actual sync will be handled by SyncManager
      // This method is mainly for monitoring and cleanup
      
    } catch (e) {
      Logger.e('Error syncing pending learned words', e, null, 'LearnedWordsService');
    }
  }

  /// Unmark a word as learned (remove from learned words)
  Future<bool> unmarkWordAsLearned(String userId, String wordId) async {
    try {
      // Check if word is actually learned
      if (!await isWordLearned(userId, wordId)) {
        Logger.i('Word is not learned, cannot unmark: $wordId', 'LearnedWordsService');
        return false; // Not learned, no action needed
      }

      // Update local cache immediately (optimistic UI)
      _learnedWordsCache[userId]?.remove(wordId);

      // Remove from offline storage immediately
      await OfflineStorageManager().removeWordCache(
        'learned_words_${userId}_$wordId',
      );

      // Also remove from Hive as backup
      final box = Hive.box<String>(_learnedWordsBoxName);
      final localKey = '${userId}_$wordId';
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
              .doc(wordId);
              
          final statsRef = _firestore
              .collection('users')
              .doc(userId);
              
          final leaderboardRef = _firestore
              .collection('leaderboard_stats')
              .doc(userId);

          // Check if word is actually learned (idempotency check in transaction)
          final existingDoc = await transaction.get(learnedWordRef);
          if (!existingDoc.exists) {
            Logger.i('[LEARNED] Word not in subcollection, skipping: $wordId (uid=$userId)', 'LearnedWordsService');
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

          Logger.i('[LEARNED] -1 -> learnedWordsCount after remove (uid=$userId, wordId=$wordId)', 'LearnedWordsService');
        });

        // Trigger SessionService refresh for real-time UI updates
        try {
          final sessionService = SessionService();
          await sessionService.refreshStats();
          Logger.i('📊 SessionService stats refreshed after word unmarked', 'LearnedWordsService');
        } catch (e) {
          Logger.w('Failed to refresh SessionService stats', 'LearnedWordsService');
        }

        Logger.i('Word unmarked as learned successfully: $wordId', 'LearnedWordsService');
      } else {
        // Queue the operation for later sync when offline
        await _queueUnlearnedWordForSync(userId, wordId);
        Logger.i('Word unmarked as learned offline, queued for sync: $wordId', 'LearnedWordsService');
      }

      return true;

    } catch (e) {
      Logger.e('Error unmarking word as learned', e, null, 'LearnedWordsService');
      
      // Queue the operation for later sync
      await _queueUnlearnedWordForSync(userId, wordId);
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

      Logger.i('Unlearned word queued for sync: $wordId', 'LearnedWordsService');
    } catch (e) {
      Logger.e('Error queuing unlearned word for sync', e, null, 'LearnedWordsService');
    }
  }
}