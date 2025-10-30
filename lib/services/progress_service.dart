// lib/services/progress_service.dart
// User Progress Tracking Service for Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firestore_schema.dart';
import 'firestore_batch_helper.dart';
import '../utils/logger.dart';

/// User Progress Tracking Service
/// Manages SRS (Spaced Repetition System) and learning progress
class ProgressService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update word progress after quiz answer
  Future<bool> updateWordProgress({
    required String userId,
    required String wordId,
    required bool isCorrect,
    String? quizType,
  }) async {
    try {
      final progressRef = _firestore.doc(
        FirestoreSchema.getUserWordProgressPath(userId, wordId),
      );

      final progressDoc = await progressRef.get();

      if (progressDoc.exists) {
        // Update existing progress
        final data = progressDoc.data() as Map<String, dynamic>;
        final currentSrsLevel = data['srsLevel'] ?? 0;
        final correctAnswers = data['correctAnswers'] ?? 0;
        final wrongAnswers = data['wrongAnswers'] ?? 0;
        final streak = data['streak'] ?? 0;

        int newSrsLevel = currentSrsLevel;
        int newStreak = streak;
        DateTime? nextReview;

        if (isCorrect) {
          // Correct answer - advance SRS level
          newSrsLevel = (currentSrsLevel + 1).clamp(0, 6);
          newStreak = streak + 1;

          // Calculate next review date based on SRS level
          nextReview = _calculateNextReviewDate(newSrsLevel);
        } else {
          // Wrong answer - reset SRS level
          newSrsLevel = 0;
          newStreak = 0;
          nextReview = DateTime.now().add(const Duration(hours: 1));
        }

        await progressRef.update({
          'srsLevel': newSrsLevel,
          'nextReview': nextReview,
          'correctAnswers': correctAnswers + (isCorrect ? 1 : 0),
          'wrongAnswers': wrongAnswers + (isCorrect ? 0 : 1),
          'lastReviewed': FieldValue.serverTimestamp(),
          'streak': newStreak,
          'mastered': newSrsLevel >= 6,
          'confidence': _calculateConfidence(
            correctAnswers + (isCorrect ? 1 : 0),
            wrongAnswers + (isCorrect ? 0 : 1),
          ),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new progress entry
        final progressData = FirestoreSchema.createUserWordProgress(
          wordId: wordId,
          srsLevel: isCorrect ? 1 : 0,
          nextReview:
              isCorrect
                  ? _calculateNextReviewDate(1)
                  : DateTime.now().add(const Duration(hours: 1)),
          correctAnswers: isCorrect ? 1 : 0,
          wrongAnswers: isCorrect ? 0 : 1,
          lastReviewed: DateTime.now(),
          mastered: false,
          streak: isCorrect ? 1 : 0,
          confidence: isCorrect ? 1.0 : 0.0,
        );

        await progressRef.set(progressData);
      }

      if (kDebugMode) {
        debugPrint('✅ Progress updated for word: $wordId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating word progress: $e');
      }
      return false;
    }
  }

  /// Get user's word progress
  Future<Map<String, dynamic>?> getWordProgress(
    String userId,
    String wordId,
  ) async {
    try {
      final doc =
          await _firestore
              .doc(FirestoreSchema.getUserWordProgressPath(userId, wordId))
              .get();

      if (!doc.exists) {
        return null;
      }

      return doc.data();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting word progress: $e');
      }
      return null;
    }
  }

  /// Get all user's word progress
  Future<List<Map<String, dynamic>>> getAllWordProgress(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting all word progress: $e');
      }
      return [];
    }
  }

  /// Get words due for review
  Future<List<String>> getWordsDueForReview(String userId) async {
    try {
      final now = DateTime.now();

      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .where('nextReview', isLessThanOrEqualTo: Timestamp.fromDate(now))
              .where('mastered', isEqualTo: false)
              .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting words due for review: $e');
      }
      return [];
    }
  }

  /// Get mastered words
  Future<List<String>> getMasteredWords(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .where('mastered', isEqualTo: true)
              .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting mastered words: $e');
      }
      return [];
    }
  }

  /// Get learning statistics
  Future<Map<String, dynamic>> getLearningStatistics(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .get();

      int totalWords = snapshot.docs.length;
      int masteredWords = 0;
      int wordsInProgress = 0;
      int totalCorrectAnswers = 0;
      int totalWrongAnswers = 0;
      double totalConfidence = 0.0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data['mastered'] == true) {
          masteredWords++;
        } else {
          wordsInProgress++;
        }

        totalCorrectAnswers += ((data['correctAnswers'] ?? 0) as num).toInt();
        totalWrongAnswers += ((data['wrongAnswers'] ?? 0) as num).toInt();
        totalConfidence += (data['confidence'] ?? 0.0).toDouble();
      }

      final accuracy =
          totalCorrectAnswers + totalWrongAnswers > 0
              ? totalCorrectAnswers / (totalCorrectAnswers + totalWrongAnswers)
              : 0.0;

      final averageConfidence =
          totalWords > 0 ? totalConfidence / totalWords : 0.0;

      return {
        'totalWords': totalWords,
        'masteredWords': masteredWords,
        'wordsInProgress': wordsInProgress,
        'totalCorrectAnswers': totalCorrectAnswers,
        'totalWrongAnswers': totalWrongAnswers,
        'accuracy': accuracy,
        'averageConfidence': averageConfidence,
      };
    } catch (e) {
      debugPrint('Error getting learning statistics: $e');
      return {};
    }
  }

  /// Get daily learning goal progress
  Future<Map<String, dynamic>> getDailyGoalProgress(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .where(
                'lastReviewed',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('lastReviewed', isLessThan: Timestamp.fromDate(endOfDay))
              .get();

      int wordsStudiedToday = snapshot.docs.length;
      int correctAnswersToday = 0;
      int wrongAnswersToday = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        correctAnswersToday += ((data['correctAnswers'] ?? 0) as num).toInt();
        wrongAnswersToday += ((data['wrongAnswers'] ?? 0) as num).toInt();
      }

      return {
        'wordsStudiedToday': wordsStudiedToday,
        'correctAnswersToday': correctAnswersToday,
        'wrongAnswersToday': wrongAnswersToday,
        'goalProgress': (wordsStudiedToday / 10.0).clamp(
          0.0,
          1.0,
        ), // Assuming 10 words per day goal
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting daily goal progress: $e');
      }
      return {};
    }
  }

  /// Reset word progress
  Future<bool> resetWordProgress(String userId, String wordId) async {
    try {
      await _firestore
          .doc(FirestoreSchema.getUserWordProgressPath(userId, wordId))
          .delete();

      if (kDebugMode) {
        debugPrint('✅ Progress reset for word: $wordId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error resetting word progress: $e');
      }
      return false;
    }
  }

  /// Reset all progress
  Future<bool> resetAllProgress(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .get();

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      if (kDebugMode) {
        debugPrint('✅ All progress reset for user: $userId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error resetting all progress: $e');
      }
      return false;
    }
  }

  /// Calculate next review date based on SRS level
  DateTime _calculateNextReviewDate(int srsLevel) {
    final now = DateTime.now();

    switch (srsLevel) {
      case 0:
        return now.add(const Duration(minutes: 1));
      case 1:
        return now.add(const Duration(minutes: 5));
      case 2:
        return now.add(const Duration(hours: 1));
      case 3:
        return now.add(const Duration(days: 1));
      case 4:
        return now.add(const Duration(days: 3));
      case 5:
        return now.add(const Duration(days: 7));
      case 6:
        return now.add(const Duration(days: 30));
      default:
        return now.add(const Duration(days: 1));
    }
  }

  /// Calculate confidence score
  double _calculateConfidence(int correctAnswers, int wrongAnswers) {
    final total = correctAnswers + wrongAnswers;
    if (total == 0) return 0.0;

    return correctAnswers / total;
  }

  /// Get SRS level distribution
  Future<Map<String, int>> getSrsLevelDistribution(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .get();

      final distribution = <String, int>{};

      for (int i = 0; i <= 6; i++) {
        distribution['level_$i'] = 0;
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final srsLevel = data['srsLevel'] ?? 0;
        distribution['level_$srsLevel'] =
            (distribution['level_$srsLevel'] ?? 0) + 1;
      }

      return distribution;
    } catch (e) {
      debugPrint('Error getting SRS level distribution: $e');
      return {};
    }
  }

  /// Get learning streak
  Future<int> getLearningStreak(String userId) async {
    try {
      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userWordProgressSubcollection)
              .orderBy('lastReviewed', descending: true)
              .limit(1)
              .get();

      if (snapshot.docs.isEmpty) {
        return 0;
      }

      final lastReview =
          snapshot.docs.first.data()['lastReviewed'] as Timestamp?;
      if (lastReview == null) {
        return 0;
      }

      final lastReviewDate = lastReview.toDate();
      final today = DateTime.now();
      final daysDifference = today.difference(lastReviewDate).inDays;

      return daysDifference <= 1 ? 1 : 0; // Simple streak calculation
    } catch (e) {
      debugPrint('Error getting learning streak: $e');
      return 0;
    }
  }

  /// Batch update multiple word progress
  Future<bool> batchUpdateProgress({
    required String userId,
    required List<Map<String, dynamic>> progressUpdates,
  }) async {
    try {
      final batchHelper = FirestoreBatchHelper(_firestore);
      final perfTask = Logger.startPerformanceTask('BatchUpdateProgress', 'ProgressService');

      for (final update in progressUpdates) {
        final wordId = update['wordId'] as String;
        final isCorrect = update['isCorrect'] as bool;

        final progressRef = _firestore.doc(
          FirestoreSchema.getUserWordProgressPath(userId, wordId),
        );

        // Get current progress
        final progressDoc = await progressRef.get();

        if (progressDoc.exists) {
          final data = progressDoc.data() as Map<String, dynamic>;
          final currentSrsLevel = data['srsLevel'] ?? 0;
          final correctAnswers = data['correctAnswers'] ?? 0;
          final wrongAnswers = data['wrongAnswers'] ?? 0;
          final streak = data['streak'] ?? 0;

          int newSrsLevel = currentSrsLevel;
          int newStreak = streak;
          DateTime? nextReview;

          if (isCorrect) {
            newSrsLevel = (currentSrsLevel + 1).clamp(0, 6);
            newStreak = streak + 1;
            nextReview = _calculateNextReviewDate(newSrsLevel);
          } else {
            newSrsLevel = 0;
            newStreak = 0;
            nextReview = DateTime.now().add(const Duration(hours: 1));
          }

          batchHelper.update(progressRef, {
            'srsLevel': newSrsLevel,
            'nextReview': nextReview,
            'correctAnswers': correctAnswers + (isCorrect ? 1 : 0),
            'wrongAnswers': wrongAnswers + (isCorrect ? 0 : 1),
            'lastReviewed': FieldValue.serverTimestamp(),
            'streak': newStreak,
            'mastered': newSrsLevel >= 6,
            'confidence': _calculateConfidence(
              correctAnswers + (isCorrect ? 1 : 0),
              wrongAnswers + (isCorrect ? 0 : 1),
            ),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new progress entry
          final progressData = FirestoreSchema.createUserWordProgress(
            wordId: wordId,
            srsLevel: isCorrect ? 1 : 0,
            nextReview:
                isCorrect
                    ? _calculateNextReviewDate(1)
                    : DateTime.now().add(const Duration(hours: 1)),
            correctAnswers: isCorrect ? 1 : 0,
            wrongAnswers: isCorrect ? 0 : 1,
            lastReviewed: DateTime.now(),
            mastered: false,
            streak: isCorrect ? 1 : 0,
            confidence: isCorrect ? 1.0 : 0.0,
          );

          batchHelper.set(progressRef, progressData);
        }
      }

      await batchHelper.commitAll();
      perfTask.finish();

      Logger.i('✅ Batch progress update completed for ${progressUpdates.length} items', 'ProgressService');
      return true;
    } catch (e) {
      Logger.e('❌ Error in batch progress update', e, null, 'ProgressService');
      return false;
    }
  }
}
