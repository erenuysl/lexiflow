// lib/services/srs_service_v2.dart
// Optimized SRS Service - Only for Quiz/Review Logic

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/word_model.dart';
import 'firestore_schema.dart';

/// SRS Service V2 - Quiz/Review Only
/// This service handles Spaced Repetition System logic exclusively for quiz sessions
/// and review scheduling. It does NOT interfere with daily word selection.
class SRSServiceV2 {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // SRS intervals in days for each level
  static const List<int> _intervals = [1, 3, 7, 14, 30, 60];
  
  // FSRS-Lite parameters
  static const double _defaultDifficulty = 5.0;
  static const double _defaultStability = 1.0;
  
  /// Update word progress after quiz answer
  /// quality: 0=again, 1=hard, 2=good, 3=easy
  Future<void> updateWordAfterQuiz({
    required String userId,
    required String wordId,
    required int quality,
    int responseTimeMs = 0,
  }) async {
    try {
      debugPrint('🧠 Updating SRS for word: $wordId, quality: $quality');
      
      // Get current progress
      final currentProgress = await _getWordProgress(userId, wordId);
      
      // Calculate new SRS values
      final updatedProgress = _calculateNewSRSValues(
        currentProgress,
        quality,
        responseTimeMs,
      );
      
      // Save to Firestore
      await _saveWordProgress(userId, wordId, updatedProgress);
      
      // Cache locally for offline access
      await _cacheWordProgress(userId, wordId, updatedProgress);
      
      debugPrint('✅ SRS updated: level ${updatedProgress['srsLevel']}, next review: ${updatedProgress['nextReview']}');
      
    } catch (e) {
      debugPrint('❌ Error updating SRS: $e');
      rethrow;
    }
  }
  
  /// Get words that need review today
  Future<List<String>> getWordsForReview(String userId, {int limit = 20}) async {
    try {
      debugPrint('🔍 Getting words for review...');
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Query words that need review
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(FirestoreSchema.userWordProgressSubcollection)
          .where('nextReview', isLessThanOrEqualTo: Timestamp.fromDate(today.add(const Duration(days: 1))))
          .where('mastered', isEqualTo: false) // Don't review mastered words
          .orderBy('nextReview')
          .limit(limit)
          .get();
      
      final wordsForReview = snapshot.docs.map((doc) => doc.id).toList();
      
      debugPrint('📚 Found ${wordsForReview.length} words for review');
      return wordsForReview;
      
    } catch (e) {
      debugPrint('❌ Error getting words for review: $e');
      return [];
    }
  }
  
  /// Get review statistics for user
  Future<Map<String, dynamic>> getReviewStatistics(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get all word progress
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection(FirestoreSchema.userWordProgressSubcollection)
          .get();
      
      int totalWords = 0;
      int masteredWords = 0;
      int wordsForReview = 0;
      int newWords = 0;
      
      final srsLevelCounts = <int, int>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalWords++;
        
        final srsLevel = data['srsLevel'] ?? 0;
        srsLevelCounts[srsLevel] = (srsLevelCounts[srsLevel] ?? 0) + 1;
        
        if (data['mastered'] == true) {
          masteredWords++;
        } else if (srsLevel == 0) {
          newWords++;
        } else {
          final nextReview = (data['nextReview'] as Timestamp?)?.toDate();
          if (nextReview != null && nextReview.isBefore(today.add(const Duration(days: 1)))) {
            wordsForReview++;
          }
        }
      }
      
      return {
        'totalWords': totalWords,
        'masteredWords': masteredWords,
        'wordsForReview': wordsForReview,
        'newWords': newWords,
        'srsLevelCounts': srsLevelCounts,
        'masteryPercentage': totalWords > 0 ? (masteredWords / totalWords) : 0.0,
      };
      
    } catch (e) {
      debugPrint('❌ Error getting review statistics: $e');
      return {};
    }
  }
  
  /// Mark word as learned (first time)
  Future<void> markWordAsLearned(String userId, String wordId) async {
    try {
      debugPrint('📖 Marking word as learned: $wordId');
      
      final initialProgress = {
        'wordId': wordId,
        'srsLevel': 1, // Start at level 1 (not 0)
        'nextReview': Timestamp.fromDate(DateTime.now().add(const Duration(days: 1))),
        'correctAnswers': 0,
        'wrongAnswers': 0,
        'lastReviewed': FieldValue.serverTimestamp(),
        'mastered': false,
        'streak': 0,
        'confidence': 0.0,
        'difficulty': _defaultDifficulty,
        'stability': _defaultStability,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _saveWordProgress(userId, wordId, initialProgress);
      await _cacheWordProgress(userId, wordId, initialProgress);
      
    } catch (e) {
      debugPrint('❌ Error marking word as learned: $e');
      rethrow;
    }
  }
  
  /// Get word progress
  Future<Map<String, dynamic>> _getWordProgress(String userId, String wordId) async {
    try {
      // Try to get from Firestore first
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection(FirestoreSchema.userWordProgressSubcollection)
          .doc(wordId)
          .get();
      
      if (doc.exists) {
        return doc.data()!;
      }
      
      // If not found, return default values
      return {
        'wordId': wordId,
        'srsLevel': 0,
        'nextReview': null,
        'correctAnswers': 0,
        'wrongAnswers': 0,
        'lastReviewed': null,
        'mastered': false,
        'streak': 0,
        'confidence': 0.0,
        'difficulty': _defaultDifficulty,
        'stability': _defaultStability,
      };
      
    } catch (e) {
      debugPrint('❌ Error getting word progress: $e');
      return {};
    }
  }
  
  /// Calculate new SRS values based on quiz performance
  Map<String, dynamic> _calculateNewSRSValues(
    Map<String, dynamic> currentProgress,
    int quality,
    int responseTimeMs,
  ) {
    final srsLevel = currentProgress['srsLevel'] ?? 0;
    final correctAnswers = currentProgress['correctAnswers'] ?? 0;
    final wrongAnswers = currentProgress['wrongAnswers'] ?? 0;
    final streak = currentProgress['streak'] ?? 0;
    final difficulty = (currentProgress['difficulty'] ?? _defaultDifficulty).toDouble();
    final stability = (currentProgress['stability'] ?? _defaultStability).toDouble();
    
    // Response time penalty
    final rtPenalty = responseTimeMs > 15000 ? 0.3 : responseTimeMs > 8000 ? 0.15 : 0.0;
    
    int newSrsLevel = srsLevel;
    int newStreak = streak;
    int newCorrectAnswers = correctAnswers;
    int newWrongAnswers = wrongAnswers;
    double newDifficulty = difficulty;
    double newStability = stability;
    bool mastered = false;
    
    switch (quality) {
      case 0: // Again (wrong answer)
        newSrsLevel = (srsLevel > 1) ? srsLevel - 1 : 1; // Don't go below 1
        newStreak = 0;
        newWrongAnswers++;
        newDifficulty = (difficulty + 1.0 + rtPenalty).clamp(1.0, 10.0);
        newStability = (stability * 0.5).clamp(0.5, 3650.0);
        break;
        
      case 1: // Hard (correct but difficult)
        // Stay at same level or slight increase
        newSrsLevel = srsLevel;
        newStreak = streak + 1;
        newCorrectAnswers++;
        newDifficulty = (difficulty + 0.3 + rtPenalty).clamp(1.0, 10.0);
        newStability = (stability * 0.9 + 1).clamp(1.0, 3650.0);
        break;
        
      case 2: // Good (correct answer)
        newSrsLevel = (srsLevel + 1).clamp(1, 6);
        newStreak = streak + 1;
        newCorrectAnswers++;
        newDifficulty = (difficulty - 0.2 - rtPenalty).clamp(1.0, 10.0);
        newStability = (stability * 1.6 + 1).clamp(1.0, 3650.0);
        break;
        
      case 3: // Easy (very easy answer)
        newSrsLevel = (srsLevel + 2).clamp(1, 6); // Bigger jump
        newStreak = streak + 1;
        newCorrectAnswers++;
        newDifficulty = (difficulty - 0.5 - rtPenalty).clamp(1.0, 10.0);
        newStability = (stability * 2.2 + 1).clamp(1.0, 3650.0);
        break;
    }
    
    // Check if word is mastered (level 6 with good streak)
    if (newSrsLevel >= 6 && newStreak >= 3) {
      mastered = true;
    }
    
    // Calculate next review date
    final nextReviewDays = mastered ? 365 : _calculateNextReviewInterval(newSrsLevel, newStability);
    final nextReview = DateTime.now().add(Duration(days: nextReviewDays));
    
    // Calculate confidence based on performance
    final totalAnswers = newCorrectAnswers + newWrongAnswers;
    final confidence = totalAnswers > 0 ? (newCorrectAnswers / totalAnswers) : 0.0;
    
    return {
      'wordId': currentProgress['wordId'],
      'srsLevel': newSrsLevel,
      'nextReview': Timestamp.fromDate(nextReview),
      'correctAnswers': newCorrectAnswers,
      'wrongAnswers': newWrongAnswers,
      'lastReviewed': FieldValue.serverTimestamp(),
      'mastered': mastered,
      'streak': newStreak,
      'confidence': confidence,
      'difficulty': newDifficulty,
      'stability': newStability,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Calculate next review interval based on SRS level and stability
  int _calculateNextReviewInterval(int srsLevel, double stability) {
    if (srsLevel <= 0) return 1;
    
    // Use stability for more personalized intervals
    final baseInterval = _intervals[(srsLevel - 1).clamp(0, _intervals.length - 1)];
    final stabilityMultiplier = (stability / _defaultStability).clamp(0.5, 3.0);
    
    return (baseInterval * stabilityMultiplier).round().clamp(1, 365);
  }
  
  /// Save word progress to Firestore
  Future<void> _saveWordProgress(String userId, String wordId, Map<String, dynamic> progress) async {
    try {
      final path = FirestoreSchema.getUserWordProgressPath(userId, wordId);
      await _firestore.doc(path).set(progress, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error saving word progress to Firestore: $e');
      rethrow;
    }
  }
  
  /// Cache word progress locally
  Future<void> _cacheWordProgress(String userId, String wordId, Map<String, dynamic> progress) async {
    try {
      final box = await Hive.openBox('srs_progress_cache');
      final key = '${userId}_$wordId';
      
      // Convert Firestore types for local storage
      final cacheData = Map<String, dynamic>.from(progress);
      
      // Convert Timestamp to String
      if (cacheData['nextReview'] is Timestamp) {
        cacheData['nextReview'] = (cacheData['nextReview'] as Timestamp).toDate().toIso8601String();
      }
      
      // Remove FieldValue types
      cacheData.remove('lastReviewed');
      cacheData.remove('updatedAt');
      cacheData['cachedAt'] = DateTime.now().toIso8601String();
      
      await box.put(key, cacheData);
    } catch (e) {
      debugPrint('❌ Error caching word progress: $e');
    }
  }
  
  /// Get SRS level description
  static String getSRSLevelDescription(int level) {
    switch (level) {
      case 0:
        return 'Yeni';
      case 1:
        return 'Öğreniyor';
      case 2:
        return 'Tanıdık';
      case 3:
        return 'Bilinen';
      case 4:
        return 'İyi Bilinen';
      case 5:
        return 'Çok İyi';
      case 6:
        return 'Uzman';
      default:
        return level > 6 ? 'Uzman' : 'Yeni';
    }
  }
  
  /// Get SRS level color
  static String getSRSLevelColor(int level) {
    switch (level) {
      case 0:
        return '#9E9E9E'; // Grey
      case 1:
        return '#F44336'; // Red
      case 2:
        return '#FF9800'; // Orange
      case 3:
        return '#FFEB3B'; // Yellow
      case 4:
        return '#8BC34A'; // Light Green
      case 5:
        return '#4CAF50'; // Green
      case 6:
        return '#2E7D32'; // Dark Green
      default:
        return level > 6 ? '#2E7D32' : '#9E9E9E';
    }
  }
  
  /// Check if word needs review
  static bool needsReview(DateTime? nextReviewDate) {
    if (nextReviewDate == null) return false;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reviewDate = DateTime(
      nextReviewDate.year,
      nextReviewDate.month,
      nextReviewDate.day,
    );
    
    return reviewDate.isBefore(today) || reviewDate.isAtSameMomentAs(today);
  }
  
  /// Reset word progress (for testing or user request)
  Future<void> resetWordProgress(String userId, String wordId) async {
    try {
      debugPrint('🔄 Resetting progress for word: $wordId');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(FirestoreSchema.userWordProgressSubcollection)
          .doc(wordId)
          .delete();
      
      // Remove from cache
      final box = await Hive.openBox('srs_progress_cache');
      final key = '${userId}_$wordId';
      await box.delete(key);
      
    } catch (e) {
      debugPrint('❌ Error resetting word progress: $e');
      rethrow;
    }
  }
}