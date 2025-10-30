// lib/services/firestore_word_service.dart
// Complete Firestore-based Word Service

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firestore_schema.dart';
import 'firestore_cache_helper.dart';
import '../models/word_model.dart';
import '../utils/logger.dart';

/// Firestore-based Word Service
/// Replaces Hive-based word storage with Firestore
class FirestoreWordService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for better performance with size limits
  final Map<String, Word> _wordCache = {};
  final Map<String, List<Word>> _listCache = {};
  
  // Cache size limits
  static const int _maxWordCacheSize = 500; // Maximum number of words in cache
  static const int _maxListCacheSize = 50; // Maximum number of lists in cache
  
  // LRU tracking for cache management
  final List<String> _wordCacheLRU = []; // Track word access order
  final List<String> _listCacheLRU = []; // Track list access order
  
  /// Clear all caches
  void clearCache() {
    _wordCache.clear();
    _listCache.clear();
    _wordCacheLRU.clear();
    _listCacheLRU.clear();
    debugPrint('FirestoreWordService: Cache cleared');
  }
  
  /// Dispose method to clean up resources
  void dispose() {
    clearCache();
    debugPrint('FirestoreWordService: Disposed');
  }

  /// Get all public words with pagination
  Future<List<Word>> getAllWords({
    int limit = 50,
    DocumentSnapshot? startAfter,
    String? difficulty,
    List<String>? tags,
    bool forceRefresh = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(FirestoreSchema.publicWordsCollection)
          .orderBy('word')
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }

      if (tags != null && tags.isNotEmpty) {
        query = query.where('tags', arrayContainsAny: tags);
      }
      
      final perfTask = Logger.startPerformanceTask('GetAllWords', 'FirestoreWordService');
      
      // Use cache helper for collection query
      final results = await FirestoreCacheHelper.getCollection<Word>(
        query: query,
        mapper: (data, id) => _mapDocumentToWord(id, data),
        forceRefresh: forceRefresh,
        cacheDuration: const Duration(minutes: 30), // Cache for 30 minutes
      );
      
      perfTask.finish();
      Logger.d('Retrieved ${results.length} words', 'FirestoreWordService');
      
      return results;
    } catch (e) {
      Logger.e('Error getting all words', e, null, 'FirestoreWordService');
      return [];
    }
  }

  /// Get words by SRS level for daily learning
  Future<List<Word>> getDailyWordsWithSRS(String userId) async {
    try {
      debugPrint('🔍 Getting daily words for userId: $userId');
      final now = DateTime.now();

      // Sanitize userId by using the schema method
      final statsPath = FirestoreSchema.getUserStatsPath(userId);
      final sanitizedUserId =
          statsPath.split('/')[1]; // Extract sanitized userId
      debugPrint('🔍 Sanitized userId: $sanitizedUserId');

      // Get user's word progress
      final progressSnapshot =
          await _firestore
              .collection('users')
              .doc(sanitizedUserId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .where('nextReview', isLessThanOrEqualTo: Timestamp.fromDate(now))
              .limit(20)
              .get();

      if (progressSnapshot.docs.isEmpty) {
        // No words to review, get new words
        return await getNewWords(userId, limit: 10);
      }

      // Get words that need review
      final wordIds = progressSnapshot.docs.map((doc) => doc.id).toList();
      final words = <Word>[];

      for (final wordId in wordIds) {
        final word = await getWordById(wordId);
        words.add(word);
            }

      return words;
    } catch (e) {
      debugPrint('Error getting daily words with SRS: $e');
      return await getNewWords(userId, limit: 10);
    }
  }

  /// Get new words for user
  Future<List<Word>> getNewWords(String userId, {int limit = 10}) async {
    try {
      debugPrint('🔍 Getting new words for userId: $userId');

      // Sanitize userId by using the schema method
      final statsPath = FirestoreSchema.getUserStatsPath(userId);
      final sanitizedUserId =
          statsPath.split('/')[1]; // Extract sanitized userId

      // Get words user hasn't studied yet
      final progressSnapshot =
          await _firestore
              .collection('users')
              .doc(sanitizedUserId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .get();

      final studiedWordIds = progressSnapshot.docs.map((doc) => doc.id).toSet();

      // Get random words not yet studied
      final wordsSnapshot =
          await _firestore
              .collection(FirestoreSchema.publicWordsCollection)
              .where('isCustom', isEqualTo: false)
              .limit(limit * 2) // Get more to filter
              .get();

      final availableWords =
          wordsSnapshot.docs
              .where((doc) => !studiedWordIds.contains(doc.id))
              .take(limit)
              .map((doc) {
                final data = doc.data();
                return _mapDocumentToWord(doc.id, data);
              })
              .toList();

      return availableWords;
    } catch (e) {
      debugPrint('Error getting new words: $e');
      return [];
    }
  }

  /// Get word by ID
  Future<Word> getWordById(String wordId, {bool forceRefresh = false}) async {
    try {
      final docRef = _firestore.doc(FirestoreSchema.getPublicWordPath(wordId));
      
      final word = await FirestoreCacheHelper.getDocument<Word>(
        reference: docRef,
        mapper: (data, id) => data != null ? _mapDocumentToWord(id, data) : Word(
          word: 'Error: Word not found',
          meaning: 'Error: Word not found',
          example: '',
          tr: '',
          exampleSentence: '',
          tags: [],
          isCustom: false,
        ),
        forceRefresh: forceRefresh,
      );
      
      return word ?? Word(
        word: 'error',
        meaning: 'Error loading word',
        example: '',
        tr: '',
        exampleSentence: '',
        tags: [],
        isCustom: false,
      );
    } catch (e) {
      Logger.e('Error getting word by ID', e, null, 'FirestoreWordService');
      // Return an empty word as fallback instead of null
      return Word(
        word: 'error',
        meaning: 'Error loading word',
        example: '',
        tr: '',
        exampleSentence: '',
        tags: [],
        isCustom: false,
      );
    }
  }

  /// Search words
  Future<List<Word>> searchWords(String query, {int limit = 20}) async {
    try {
      if (query.isEmpty) return [];

      final snapshot =
          await _firestore
              .collection(FirestoreSchema.publicWordsCollection)
              .where('word', isGreaterThanOrEqualTo: query.toLowerCase())
              .where('word', isLessThan: '${query.toLowerCase()}\uf8ff')
              .limit(limit)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _mapDocumentToWord(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint('Error searching words: $e');
      return [];
    }
  }

  /// Get words by difficulty
  Future<List<Word>> getWordsByDifficulty(
    String difficulty, {
    int limit = 50,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreSchema.publicWordsCollection)
              .where('difficulty', isEqualTo: difficulty)
              .limit(limit)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _mapDocumentToWord(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting words by difficulty: $e');
      return [];
    }
  }

  /// Get words by tags
  Future<List<Word>> getWordsByTags(List<String> tags, {int limit = 50}) async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreSchema.publicWordsCollection)
              .where('tags', arrayContainsAny: tags)
              .limit(limit)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _mapDocumentToWord(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting words by tags: $e');
      return [];
    }
  }

  /// Get random words for quiz
  Future<List<Word>> getRandomWords(int count, {String? difficulty}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(FirestoreSchema.publicWordsCollection)
          .where('isCustom', isEqualTo: false);

      if (difficulty != null) {
        query = query.where('difficulty', isEqualTo: difficulty);
      }

      final snapshot = await query.limit(count * 2).get();

      // Shuffle and take requested count
      final words =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return _mapDocumentToWord(doc.id, data);
          }).toList();

      words.shuffle();
      return words.take(count).toList();
    } catch (e) {
      debugPrint('Error getting random words: $e');
      return [];
    }
  }

  /// Add custom word
  Future<bool> addCustomWord(String userId, Word word) async {
    try {
      final wordId = _generateWordId(word.word);
      debugPrint('🔍 Adding custom word: ${word.word} (wordId: $wordId)');

      final wordPath = FirestoreSchema.getPublicWordPath(wordId);
      debugPrint('🔍 Word path: $wordPath');

      final wordData = FirestoreSchema.createPublicWord(
        wordId: wordId,
        word: word.word,
        meaning: word.meaning,
        tr: word.tr,
        exampleSentence: word.exampleSentence,
        tags: word.tags,
        isCustom: true,
        createdBy: userId,
      );

      await _firestore.doc(wordPath).set(wordData);

      // Clear cache
      _wordCache.remove(wordId);

      debugPrint('✅ Custom word added: ${word.word}');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding custom word: $e');
      return false;
    }
  }

  /// Update custom word
  Future<bool> updateCustomWord(String userId, String wordId, Word word) async {
    try {
      final wordData = FirestoreSchema.createPublicWord(
        wordId: wordId,
        word: word.word,
        meaning: word.meaning,
        tr: word.tr,
        exampleSentence: word.exampleSentence,
        tags: word.tags,
        isCustom: true,
        createdBy: userId,
      );

      await _firestore
          .doc(FirestoreSchema.getPublicWordPath(wordId))
          .update(wordData);

      // Update cache
      _wordCache[wordId] = word;

      debugPrint('✅ Custom word updated: ${word.word}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating custom word: $e');
      return false;
    }
  }

  /// Delete custom word
  Future<bool> deleteCustomWord(String userId, String wordId) async {
    try {
      await _firestore.doc(FirestoreSchema.getPublicWordPath(wordId)).delete();

      // Remove from cache
      _wordCache.remove(wordId);

      debugPrint('✅ Custom word deleted: $wordId');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting custom word: $e');
      return false;
    }
  }

  /// Get user's custom words
  Future<List<Word>> getCustomWords(String userId) async {
    try {
      debugPrint('🔍 Getting custom words for userId: $userId');

      // Note: createdBy field should also be sanitized when stored
      final snapshot =
          await _firestore
              .collection(FirestoreSchema.publicWordsCollection)
              .where('isCustom', isEqualTo: true)
              .where('createdBy', isEqualTo: userId)
              .orderBy('word')
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return _mapDocumentToWord(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting custom words: $e');
      return [];
    }
  }

  /// Get favorite words
  Future<List<Word>> getFavoriteWords(String userId) async {
    try {
      debugPrint('🔍 Getting favorite words for userId: $userId');

      // Sanitize userId by using the schema method
      final statsPath = FirestoreSchema.getUserStatsPath(userId);
      final sanitizedUserId =
          statsPath.split('/')[1]; // Extract sanitized userId

      final favoritesSnapshot =
          await _firestore
              .collection('users')
              .doc(sanitizedUserId)
              .collection('favorites')
              .get();

      if (favoritesSnapshot.docs.isEmpty) {
        return [];
      }

      final favoriteWordIds =
          favoritesSnapshot.docs.map((doc) => doc.id).toList();
      final words = <Word>[];

      for (final wordId in favoriteWordIds) {
        final word = await getWordById(wordId);
        words.add(word);
            }

      return words;
    } catch (e) {
      debugPrint('Error getting favorite words: $e');
      return [];
    }
  }

  /// Toggle favorite word
  Future<bool> toggleFavoriteWord(String userId, String wordId) async {
    try {
      debugPrint('🔍 Toggling favorite for userId: $userId, wordId: $wordId');

      // Sanitize userId by using the schema method
      final statsPath = FirestoreSchema.getUserStatsPath(userId);
      final sanitizedUserId =
          statsPath.split('/')[1]; // Extract sanitized userId

      final favoriteRef = _firestore
          .collection('users')
          .doc(sanitizedUserId)
          .collection('favorites')
          .doc(wordId);

      final favoriteDoc = await favoriteRef.get();

      if (favoriteDoc.exists) {
        // Remove from favorites
        await favoriteRef.delete();
        debugPrint('✅ Removed from favorites: $wordId');
      } else {
        // Add to favorites
        await favoriteRef.set({
          'wordId': wordId,
          'addedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Added to favorites: $wordId');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error toggling favorite word: $e');
      return false;
    }
  }

  /// Check if word is favorite
  Future<bool> isFavoriteWord(String userId, String wordId) async {
    try {
      // Sanitize userId by using the schema method
      final statsPath = FirestoreSchema.getUserStatsPath(userId);
      final sanitizedUserId =
          statsPath.split('/')[1]; // Extract sanitized userId

      final favoriteDoc =
          await _firestore
              .collection('users')
              .doc(sanitizedUserId)
              .collection('favorites')
              .doc(wordId)
              .get();

      return favoriteDoc.exists;
    } catch (e) {
      debugPrint('Error checking favorite word: $e');
      return false;
    }
  }

  /// Get word statistics
  Future<Map<String, int>> getWordStatistics() async {
    try {
      final snapshot =
          await _firestore
              .collection(FirestoreSchema.publicWordsCollection)
              .get();

      int totalWords = snapshot.docs.length;
      int customWords = 0;
      int beginnerWords = 0;
      int intermediateWords = 0;
      int advancedWords = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data['isCustom'] == true) customWords++;

        final difficulty = data['difficulty'] as String?;
        switch (difficulty) {
          case 'beginner':
            beginnerWords++;
            break;
          case 'intermediate':
            intermediateWords++;
            break;
          case 'advanced':
            advancedWords++;
            break;
        }
      }

      return {
        'totalWords': totalWords,
        'customWords': customWords,
        'beginnerWords': beginnerWords,
        'intermediateWords': intermediateWords,
        'advancedWords': advancedWords,
      };
    } catch (e) {
      debugPrint('Error getting word statistics: $e');
      return {};
    }
  }

  /// Map Firestore document to Word model
  Word _mapDocumentToWord(String wordId, Map<String, dynamic> data) {
    return Word(
      word: data['word'] ?? '',
      meaning: data['meaning'] ?? '',
      example: data['exampleSentence'] ?? '',
      tr: data['tr'] ?? '',
      exampleSentence: data['exampleSentence'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      isCustom: data['isCustom'] ?? false,
    );
  }

  /// Generate word ID from word text
  String _generateWordId(String word) {
    return word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  /// Check if today is extended (for backward compatibility)
  bool isTodayExtended() {
    // This can be implemented based on user activity
    return false;
  }
}
