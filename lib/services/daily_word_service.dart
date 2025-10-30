// lib/services/daily_word_service.dart
// Daily Word System with 10 free + 5 ad bonus words

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../models/word_model.dart';
import 'firestore_schema.dart';
import 'ad_service.dart';

/// Daily Word Service
/// Manages daily word assignments with smart selection algorithm
class DailyWordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdService _adService = AdService();

  static const int dailyWordCount = 10;
  static const int bonusWordCount = 5;
  static const int totalMaxWords = dailyWordCount + bonusWordCount;

  /// Get today's date string in UTC (YYYY-MM-DD format)
  String _getTodayDateString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get next reset time (midnight UTC)
  DateTime getNextResetTime() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
    return tomorrow;
  }

  /// Get time remaining until reset
  Duration getTimeUntilReset() {
    final now = DateTime.now().toUtc();
    final nextReset = getNextResetTime();
    return nextReset.difference(now);
  }

  /// Get today's words for a user
  Future<Map<String, dynamic>> getTodaysWords(String userId) async {
    try {
      final today = _getTodayDateString();
      final path = FirestoreSchema.getDailyWordsPath(userId, today);

      debugPrint('📅 Getting daily words for $today');

      final doc = await _firestore.doc(path).get();

      if (!doc.exists) {
        debugPrint('🆕 No daily words found, generating new set...');
        return await generateDailyWords(userId);
      }

      final data = doc.data()!;
      debugPrint(
        '✅ Found existing daily words: ${data['dailyWords'].length} words',
      );

      return {
        'date': data['date'],
        'dailyWords': List<String>.from(data['dailyWords'] ?? []),
        'extraWords': List<String>.from(data['extraWords'] ?? []),
        'completedWords': List<String>.from(data['completedWords'] ?? []),
        'hasWatchedAd': data['hasWatchedAd'] ?? false,
      };
    } catch (e) {
      debugPrint('❌ Error getting today\'s words: $e');
      rethrow;
    }
  }

  /// Generate daily words for a user
  Future<Map<String, dynamic>> generateDailyWords(String userId) async {
    try {
      final today = _getTodayDateString();
      debugPrint('🎲 Generating $dailyWordCount daily words for $userId');

      // Get word IDs using smart selection algorithm
      final wordIds = await _selectDailyWords(userId, dailyWordCount);

      if (wordIds.isEmpty) {
        debugPrint('⚠️ No words available for daily selection');
        return {
          'date': today,
          'dailyWords': <String>[],
          'extraWords': <String>[],
          'completedWords': <String>[],
          'hasWatchedAd': false,
        };
      }

      // Create daily words document
      final dailyWordsData = FirestoreSchema.createDailyWords(
        date: today,
        dailyWords: wordIds,
      );

      final path = FirestoreSchema.getDailyWordsPath(userId, today);
      await _firestore.doc(path).set(dailyWordsData);

      debugPrint('✅ Generated ${wordIds.length} daily words');

      return {
        'date': today,
        'dailyWords': wordIds,
        'extraWords': <String>[],
        'completedWords': <String>[],
        'hasWatchedAd': false,
      };
    } catch (e) {
      debugPrint('❌ Error generating daily words: $e');
      rethrow;
    }
  }

  /// Smart word selection algorithm
  Future<List<String>> _selectDailyWords(String userId, int count) async {
    try {
      debugPrint('🧠 Running smart word selection algorithm...');

      // Get user's word progress
      final progressSnapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .get();

      final userProgress = <String, Map<String, dynamic>>{};
      for (final doc in progressSnapshot.docs) {
        userProgress[doc.id] = doc.data();
      }

      // Get all available words
      final wordsSnapshot =
          await _firestore
              .collection(FirestoreSchema.publicWordsCollection)
              .limit(500) // Limit for performance
              .get();

      if (wordsSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No public words available');
        return [];
      }

      // Get recently used words (last 7 days)
      final recentlyUsed = await _getRecentlyUsedWords(userId, 7);

      // Categorize words
      final unlearnedWords = <String>[];
      final lowSrsWords = <String>[];
      final otherWords = <String>[];

      for (final doc in wordsSnapshot.docs) {
        final wordId = doc.id;

        // Skip recently used words
        if (recentlyUsed.contains(wordId)) continue;

        final progress = userProgress[wordId];

        if (progress == null) {
          // Unlearned word
          unlearnedWords.add(wordId);
        } else {
          final srsLevel = progress['srsLevel'] ?? 0;
          if (srsLevel <= 2) {
            // Low SRS level (still learning)
            lowSrsWords.add(wordId);
          } else {
            otherWords.add(wordId);
          }
        }
      }

      debugPrint('📊 Word categories:');
      debugPrint('   - Unlearned: ${unlearnedWords.length}');
      debugPrint('   - Low SRS: ${lowSrsWords.length}');
      debugPrint('   - Other: ${otherWords.length}');
      debugPrint('   - Recently used (excluded): ${recentlyUsed.length}');

      // Select words with priority: unlearned > low SRS > random
      final selectedWords = <String>[];
      final random = Random();

      // 1. Prioritize unlearned words (60%)
      final unlearnedCount = min((count * 0.6).ceil(), unlearnedWords.length);
      if (unlearnedWords.isNotEmpty) {
        unlearnedWords.shuffle(random);
        selectedWords.addAll(unlearnedWords.take(unlearnedCount));
      }

      // 2. Add low SRS words (30%)
      final lowSrsCount = min(
        (count * 0.3).ceil(),
        min(lowSrsWords.length, count - selectedWords.length),
      );
      if (lowSrsWords.isNotEmpty && selectedWords.length < count) {
        lowSrsWords.shuffle(random);
        selectedWords.addAll(lowSrsWords.take(lowSrsCount));
      }

      // 3. Fill remaining with random words
      if (selectedWords.length < count && otherWords.isNotEmpty) {
        otherWords.shuffle(random);
        selectedWords.addAll(otherWords.take(count - selectedWords.length));
      }

      // If still not enough, use recently used words as fallback
      if (selectedWords.length < count) {
        final allWords = wordsSnapshot.docs.map((doc) => doc.id).toList();
        allWords.shuffle(random);
        for (final wordId in allWords) {
          if (!selectedWords.contains(wordId)) {
            selectedWords.add(wordId);
            if (selectedWords.length >= count) break;
          }
        }
      }

      debugPrint('✅ Selected ${selectedWords.length} words');
      return selectedWords.take(count).toList();
    } catch (e) {
      debugPrint('❌ Error in word selection algorithm: $e');
      return [];
    }
  }

  /// Get recently used words from last N days
  Future<Set<String>> _getRecentlyUsedWords(String userId, int days) async {
    try {
      final recentWords = <String>{};
      final now = DateTime.now().toUtc();

      for (int i = 1; i <= days; i++) {
        final date = now.subtract(Duration(days: i));
        final dateString =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final path = FirestoreSchema.getDailyWordsPath(userId, dateString);
        final doc = await _firestore.doc(path).get();

        if (doc.exists) {
          final data = doc.data()!;
          final dailyWords = List<String>.from(data['dailyWords'] ?? []);
          final extraWords = List<String>.from(data['extraWords'] ?? []);
          recentWords.addAll(dailyWords);
          recentWords.addAll(extraWords);
        }
      }

      return recentWords;
    } catch (e) {
      debugPrint('❌ Error getting recently used words: $e');
      return {};
    }
  }

  /// Check if user can watch ad for extra words
  Future<bool> canWatchAdForExtraWords(String userId) async {
    try {
      final today = _getTodayDateString();
      final path = FirestoreSchema.getDailyWordsPath(userId, today);
      final doc = await _firestore.doc(path).get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final hasWatchedAd = data['hasWatchedAd'] ?? false;

      return !hasWatchedAd;
    } catch (e) {
      debugPrint('❌ Error checking ad eligibility: $e');
      return false;
    }
  }

  /// Add extra words after watching ad
  Future<bool> addExtraWordsAfterAd(String userId) async {
    try {
      debugPrint('📺 User watching ad for extra words...');

      // Show rewarded ad
      final adWatched = await _adService.showRewardedAd();

      if (!adWatched) {
        debugPrint('❌ Ad not watched or failed');
        return false;
      }

      debugPrint('✅ Ad watched successfully, adding extra words...');

      // Generate extra words
      final extraWordIds = await _selectDailyWords(userId, bonusWordCount);

      if (extraWordIds.isEmpty) {
        debugPrint('⚠️ No extra words available');
        return false;
      }

      // Update daily words document
      final today = _getTodayDateString();
      final path = FirestoreSchema.getDailyWordsPath(userId, today);

      await _firestore.doc(path).update({
        'extraWords': extraWordIds,
        'hasWatchedAd': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Added ${extraWordIds.length} extra words');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding extra words: $e');
      return false;
    }
  }

  /// Mark word as completed
  Future<void> markWordAsCompleted(String userId, String wordId) async {
    try {
      final today = _getTodayDateString();
      final path = FirestoreSchema.getDailyWordsPath(userId, today);

      await _firestore.doc(path).update({
        'completedWords': FieldValue.arrayUnion([wordId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Marked word $wordId as completed');
    } catch (e) {
      debugPrint('❌ Error marking word as completed: $e');
    }
  }

  /// Get word details by ID
  Future<Word?> getWordById(String wordId) async {
    try {
      final doc =
          await _firestore
              .collection(FirestoreSchema.publicWordsCollection)
              .doc(wordId)
              .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return Word.fromJson(data);
    } catch (e) {
      debugPrint('❌ Error getting word by ID: $e');
      return null;
    }
  }

  /// Get multiple words by IDs
  Future<List<Word>> getWordsByIds(List<String> wordIds) async {
    try {
      if (wordIds.isEmpty) return [];

      final words = <Word>[];

      // Firestore 'in' query limit is 10, so batch the requests
      for (int i = 0; i < wordIds.length; i += 10) {
        final batch = wordIds.skip(i).take(10).toList();
        final snapshot =
            await _firestore
                .collection(FirestoreSchema.publicWordsCollection)
                .where(FieldPath.documentId, whereIn: batch)
                .get();

        for (final doc in snapshot.docs) {
          words.add(Word.fromJson(doc.data()));
        }
      }

      return words;
    } catch (e) {
      debugPrint('❌ Error getting words by IDs: $e');
      return [];
    }
  }

  /// Initialize ad service
  Future<void> initializeAdService() async {
    await AdService.initialize();
    await _adService.loadRewardedAd();
  }

  /// Dispose
  void dispose() {
    _adService.dispose();
  }
}
