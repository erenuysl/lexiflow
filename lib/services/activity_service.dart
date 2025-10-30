// lib/services/activity_service.dart
// User Activity Logging Service for Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'firestore_schema.dart';
import 'firestore_batch_helper.dart';
import '../utils/logger.dart';

/// User Activity Logging Service
/// Tracks user activities and learning progress
class ActivityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log quiz completion activity
  Future<bool> logQuizCompletion({
    required String userId,
    required String quizType,
    required int correctAnswers,
    required int totalQuestions,
    required int xpEarned,
    List<String>? wordIds,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final activityData = FirestoreSchema.createUserActivity(
        type: FirestoreSchema.activityTypeQuizCompleted,
        xpEarned: xpEarned,
        wordsLearned: correctAnswers,
        quizType: quizType,
        correctAnswers: correctAnswers,
        totalQuestions: totalQuestions,
        metadata: {
          ...?metadata,
          'wordIds': wordIds,
          'accuracy':
              totalQuestions > 0 ? correctAnswers / totalQuestions : 0.0,
        },
      );

      await _firestore
          .doc(FirestoreSchema.getUserActivityPath(userId, timestamp))
          .set(activityData);

      debugPrint('✅ Quiz completion logged: $quizType');
      return true;
    } catch (e) {
      debugPrint('❌ Error logging quiz completion: $e');
      return false;
    }
  }

  /// Log word learned activity
  Future<bool> logWordLearned({
    required String userId,
    required String wordId,
    required int xpEarned,
    String? learningMethod,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final activityData = FirestoreSchema.createUserActivity(
        type: FirestoreSchema.activityTypeWordLearned,
        xpEarned: xpEarned,
        wordsLearned: 1,
        wordId: wordId,
        metadata: {...?metadata, 'learningMethod': learningMethod},
      );

      await _firestore
          .doc(FirestoreSchema.getUserActivityPath(userId, timestamp))
          .set(activityData);

      debugPrint('✅ Word learned logged: $wordId');
      return true;
    } catch (e) {
      debugPrint('❌ Error logging word learned: $e');
      return false;
    }
  }

  /// Log streak update activity
  Future<bool> logStreakUpdate({
    required String userId,
    required int newStreak,
    required int xpEarned,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final activityData = FirestoreSchema.createUserActivity(
        type: FirestoreSchema.activityTypeStreakUpdated,
        xpEarned: xpEarned,
        metadata: {...?metadata, 'newStreak': newStreak},
      );

      await _firestore
          .doc(FirestoreSchema.getUserActivityPath(userId, timestamp))
          .set(activityData);

      debugPrint('✅ Streak update logged: $newStreak');
      return true;
    } catch (e) {
      debugPrint('❌ Error logging streak update: $e');
      return false;
    }
  }

  /// Log level up activity
  Future<bool> logLevelUp({
    required String userId,
    required int newLevel,
    required int xpEarned,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final activityData = FirestoreSchema.createUserActivity(
        type: FirestoreSchema.activityTypeLevelUp,
        xpEarned: xpEarned,
        metadata: {...?metadata, 'newLevel': newLevel},
      );

      await _firestore
          .doc(FirestoreSchema.getUserActivityPath(userId, timestamp))
          .set(activityData);

      debugPrint('✅ Level up logged: $newLevel');
      return true;
    } catch (e) {
      debugPrint('❌ Error logging level up: $e');
      return false;
    }
  }

  /// Log custom word added activity
  Future<bool> logCustomWordAdded({
    required String userId,
    required String wordId,
    required int xpEarned,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final activityData = FirestoreSchema.createUserActivity(
        type: FirestoreSchema.activityTypeCustomWordAdded,
        xpEarned: xpEarned,
        wordId: wordId,
        metadata: {...?metadata},
      );

      await _firestore
          .doc(FirestoreSchema.getUserActivityPath(userId, timestamp))
          .set(activityData);

      debugPrint('✅ Custom word added logged: $wordId');
      return true;
    } catch (e) {
      debugPrint('❌ Error logging custom word added: $e');
      return false;
    }
  }

  /// Get user activities with pagination
  Future<List<Map<String, dynamic>>> getUserActivities({
    required String userId,
    int limit = 50,
    DocumentSnapshot? startAfter,
    String? activityType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection(FirestoreSchema.userActivitySubcollection)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      if (activityType != null) {
        query = query.where('type', isEqualTo: activityType);
      }

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting user activities: $e');
      return [];
    }
  }

  /// Get today's activities
  Future<List<Map<String, dynamic>>> getTodayActivities(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userActivitySubcollection)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
              .orderBy('timestamp', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting today activities: $e');
      return [];
    }
  }

  /// Get activity statistics
  Future<Map<String, dynamic>> getActivityStatistics({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(userId)
          .collection(FirestoreSchema.userActivitySubcollection);

      if (startDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();

      int totalActivities = snapshot.docs.length;
      int totalXpEarned = 0;
      int totalWordsLearned = 0;
      int totalQuizzesCompleted = 0;
      int totalCorrectAnswers = 0;
      int totalQuestions = 0;

      final activityTypeCounts = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        totalXpEarned += (data['xpEarned'] ?? 0) as int;
        totalWordsLearned += (data['wordsLearned'] ?? 0) as int;

        final type = data['type'] as String?;
        if (type != null) {
          activityTypeCounts[type] = (activityTypeCounts[type] ?? 0) + 1;

          if (type == FirestoreSchema.activityTypeQuizCompleted) {
            totalQuizzesCompleted++;
            totalCorrectAnswers += ((data['correctAnswers'] ?? 0) as num).toInt();
            totalQuestions += ((data['totalQuestions'] ?? 0) as num).toInt();
          }
        }
      }

      final accuracy =
          totalQuestions > 0 ? totalCorrectAnswers / totalQuestions : 0.0;

      return {
        'totalActivities': totalActivities,
        'totalXpEarned': totalXpEarned,
        'totalWordsLearned': totalWordsLearned,
        'totalQuizzesCompleted': totalQuizzesCompleted,
        'totalCorrectAnswers': totalCorrectAnswers,
        'totalQuestions': totalQuestions,
        'accuracy': accuracy,
        'activityTypeCounts': activityTypeCounts,
      };
    } catch (e) {
      debugPrint('Error getting activity statistics: $e');
      return {};
    }
  }

  /// Get daily activity summary
  Future<Map<String, dynamic>> getDailyActivitySummary(String userId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userActivitySubcollection)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
              .get();

      int dailyXpEarned = 0;
      int dailyWordsLearned = 0;
      int dailyQuizzesCompleted = 0;
      int dailyCorrectAnswers = 0;
      int dailyQuestions = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        dailyXpEarned += (data['xpEarned'] ?? 0) as int;
        dailyWordsLearned += (data['wordsLearned'] ?? 0) as int;

        if (data['type'] == FirestoreSchema.activityTypeQuizCompleted) {
          dailyQuizzesCompleted++;
          dailyCorrectAnswers += ((data['correctAnswers'] ?? 0) as num).toInt();
          dailyQuestions += ((data['totalQuestions'] ?? 0) as num).toInt();
        }
      }

      final dailyAccuracy =
          dailyQuestions > 0 ? dailyCorrectAnswers / dailyQuestions : 0.0;

      return {
        'dailyXpEarned': dailyXpEarned,
        'dailyWordsLearned': dailyWordsLearned,
        'dailyQuizzesCompleted': dailyQuizzesCompleted,
        'dailyCorrectAnswers': dailyCorrectAnswers,
        'dailyQuestions': dailyQuestions,
        'dailyAccuracy': dailyAccuracy,
        'activitiesCount': snapshot.docs.length,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting daily activity summary: $e');
      }
      return {};
    }
  }

  /// Get weekly activity summary
  Future<Map<String, dynamic>> getWeeklyActivitySummary(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDay = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      final endOfWeek = startOfWeekDay.add(const Duration(days: 7));

      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userActivitySubcollection)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekDay),
              )
              .where('timestamp', isLessThan: Timestamp.fromDate(endOfWeek))
              .get();

      int weeklyXpEarned = 0;
      int weeklyWordsLearned = 0;
      int weeklyQuizzesCompleted = 0;
      int weeklyCorrectAnswers = 0;
      int weeklyQuestions = 0;

      final dailyBreakdown = <String, Map<String, int>>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;

        if (timestamp != null) {
          final date = timestamp.toDate();
          final dayKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

          if (!dailyBreakdown.containsKey(dayKey)) {
            dailyBreakdown[dayKey] = {
              'xpEarned': 0,
              'wordsLearned': 0,
              'quizzesCompleted': 0,
            };
          }

          final xpEarned = data['xpEarned'] ?? 0;
          final wordsLearned = data['wordsLearned'] ?? 0;

          weeklyXpEarned += (xpEarned as int);
          weeklyWordsLearned += (wordsLearned as int);

          dailyBreakdown[dayKey]!['xpEarned'] =
              dailyBreakdown[dayKey]!['xpEarned']! + xpEarned;
          dailyBreakdown[dayKey]!['wordsLearned'] =
              dailyBreakdown[dayKey]!['wordsLearned']! + wordsLearned;

          if (data['type'] == FirestoreSchema.activityTypeQuizCompleted) {
            weeklyQuizzesCompleted++;
            weeklyCorrectAnswers += ((data['correctAnswers'] ?? 0) as num).toInt();
            weeklyQuestions += ((data['totalQuestions'] ?? 0) as num).toInt();

            dailyBreakdown[dayKey]!['quizzesCompleted'] =
                dailyBreakdown[dayKey]!['quizzesCompleted']! + 1;
          }
        }
      }

      final weeklyAccuracy =
          weeklyQuestions > 0 ? weeklyCorrectAnswers / weeklyQuestions : 0.0;

      return {
        'weeklyXpEarned': weeklyXpEarned,
        'weeklyWordsLearned': weeklyWordsLearned,
        'weeklyQuizzesCompleted': weeklyQuizzesCompleted,
        'weeklyCorrectAnswers': weeklyCorrectAnswers,
        'weeklyQuestions': weeklyQuestions,
        'weeklyAccuracy': weeklyAccuracy,
        'dailyBreakdown': dailyBreakdown,
        'activitiesCount': snapshot.docs.length,
      };
    } catch (e) {
      debugPrint('Error getting weekly activity summary: $e');
      return {};
    }
  }

  /// Delete old activities (cleanup)
  Future<bool> deleteOldActivities(
    String userId, {
    int daysToKeep = 365,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final snapshot =
          await _firestore
              .collection('users')
              .doc(userId)
              .collection(FirestoreSchema.userActivitySubcollection)
              .where('timestamp', isLessThan: Timestamp.fromDate(cutoffDate))
              .get();

      if (snapshot.docs.isEmpty) {
        return true;
      }

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      debugPrint('✅ Deleted ${snapshot.docs.length} old activities');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting old activities: $e');
      return false;
    }
  }

  /// Batch log multiple activities
  Future<bool> batchLogActivities({
    required String userId,
    required List<Map<String, dynamic>> activities,
  }) async {
    try {
      final batchHelper = FirestoreBatchHelper(_firestore);
      final perfTask = Logger.startPerformanceTask('BatchLogActivities', 'ActivityService');

      for (final activity in activities) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final activityData = FirestoreSchema.createUserActivity(
          type: activity['type'] as String,
          xpEarned: activity['xpEarned'] as int? ?? 0,
          wordsLearned: activity['wordsLearned'] as int? ?? 0,
          quizType: activity['quizType'] as String?,
          correctAnswers: activity['correctAnswers'] as int? ?? 0,
          totalQuestions: activity['totalQuestions'] as int? ?? 0,
          wordId: activity['wordId'] as String?,
          metadata: activity['metadata'] as Map<String, dynamic>?,
        );

        batchHelper.set(
          _firestore.doc(
            FirestoreSchema.getUserActivityPath(userId, timestamp),
          ),
          activityData,
        );
      }

      await batchHelper.commitAll();
      perfTask.finish();

      Logger.i('✅ Batch logged ${activities.length} activities', 'ActivityService');
      return true;
    } catch (e) {
      Logger.e('❌ Error batch logging activities', e, null, 'ActivityService');
      return false;
    }
  }
}
