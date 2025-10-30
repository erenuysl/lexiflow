// lib/services/statistics_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

class StatisticsService {
  static const String _tag = 'StatisticsService';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache for weekly activity data
  static final Map<String, _CachedWeeklyData> _weeklyActivityCache = {};
  static const Duration _cacheExpiration = Duration(minutes: 5);

  /// Record daily activity with transaction for atomic FieldValue operations
  Future<void> recordActivity({
    required String userId,
    required int xpEarned,
    int wordsLearned = 0,
    int quizzesCompleted = 0,
  }) async {
    try {
      final today = _getTodayKey();
      Logger.d('Recording activity: date=$today, xp=$xpEarned, words=$wordsLearned, quizzes=$quizzesCompleted', _tag);
      
      final activityRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('user_activity')
          .doc(today);

      // Use transaction to ensure atomic updates with FieldValue operations
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(activityRef);
        
        if (doc.exists) {
          // Update existing document with FieldValue increments
          transaction.update(activityRef, {
            'xpEarned': FieldValue.increment(xpEarned),
            'wordsLearned': FieldValue.increment(wordsLearned),
            'quizzesCompleted': FieldValue.increment(quizzesCompleted),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new document with initial values
          transaction.set(activityRef, {
            'date': today,
            'xpEarned': xpEarned,
            'wordsLearned': wordsLearned,
            'quizzesCompleted': quizzesCompleted,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });

      // Invalidate cache when new activity is recorded
      _weeklyActivityCache.remove(userId);

      Logger.success('Activity recorded for $today (XP: $xpEarned, Words: $wordsLearned, Quizzes: $quizzesCompleted)', _tag);
    } catch (e, stackTrace) {
      Logger.e('Failed to record activity for user $userId', e, stackTrace, _tag);
      rethrow;
    }
  }

  /// Get weekly activity data with caching and optimization
  Stream<List<Map<String, dynamic>>> getWeeklyActivity(String userId) {
    final startDate = DateTime.now().subtract(const Duration(days: 7));
    final startDateStr = _formatDate(startDate);
    
    Logger.d('Fetching weekly activity for user $userId from $startDateStr', _tag);

    // Check cache first
    final cachedData = _weeklyActivityCache[userId];
    if (cachedData != null && !cachedData.isExpired) {
      Logger.d('Returning cached weekly activity data', _tag);
      return Stream.value(cachedData.data);
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('user_activity')
        .where('date', isGreaterThanOrEqualTo: startDateStr)
        .snapshots()
        .map((snapshot) {
          Logger.d('Weekly activity snapshot received: ${snapshot.docs.length} days', _tag);
          
          final data = snapshot.docs.map((doc) {
            final docData = doc.data();
            // Safe type casting to prevent FieldValue errors
            return {
              'date': docData['date'],
              'xpEarned': docData['xpEarned'] is int ? docData['xpEarned'] : 0,
              'wordsLearned': docData['wordsLearned'] is int ? docData['wordsLearned'] : 0,
              'quizzesCompleted': docData['quizzesCompleted'] is int ? docData['quizzesCompleted'] : 0,
              'lastUpdated': docData['lastUpdated'],
            };
          }).toList();
          
          // Cache the data
          _weeklyActivityCache[userId] = _CachedWeeklyData(data);
          
          return data;
        })
        .handleError((error) {
          Logger.e('Error fetching weekly activity', error, null, _tag);
          // Return cached data if available, otherwise empty list
          final cachedData = _weeklyActivityCache[userId];
          if (cachedData != null) {
            Logger.d('Returning cached data due to error', _tag);
            return cachedData.data;
          }
          return <Map<String, dynamic>>[];
        });
  }

  /// Clear cache for a specific user (useful for testing or manual refresh)
  static void clearCache([String? userId]) {
    if (userId != null) {
      _weeklyActivityCache.remove(userId);
    } else {
      _weeklyActivityCache.clear();
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return _formatDate(now);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Log review start for FSRS/Review Analytics
  Future<void> logReviewStart({required String userId, required String wordId}) async {
    try {
      Logger.d('Logging review start for word $wordId', _tag);
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('review_analytics')
          .add({
        'wordId': wordId,
        'reviewStartTime': FieldValue.serverTimestamp(),
        'type': 'review_start',
      });
      
      Logger.success('Review start logged for word $wordId', _tag);
    } catch (e, stackTrace) {
      Logger.e('Failed to log review start for word $wordId', e, stackTrace, _tag);
      // Don't rethrow - analytics failures shouldn't break the app
    }
  }

  /// Log review answered for FSRS/Review Analytics
  Future<void> logReviewAnswered({
    required String userId,
    required String wordId,
    required int rating,
    required Duration reviewTime,
  }) async {
    return logReviewCompletion(
      userId: userId,
      wordId: wordId,
      rating: rating,
      reviewTime: reviewTime,
    );
  }

  /// Log session complete for FSRS/Review Analytics
  Future<void> logSessionComplete({
    required String userId,
    required int totalWords,
    required Duration sessionTime,
  }) async {
    try {
      Logger.d('Logging session completion for $totalWords words', _tag);
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('review_analytics')
          .add({
        'totalWords': totalWords,
        'sessionTime': sessionTime.inMilliseconds,
        'completedAt': FieldValue.serverTimestamp(),
        'type': 'session_completion',
      });
      
      Logger.success('Session completion logged for $totalWords words', _tag);
    } catch (e, stackTrace) {
      Logger.e('Failed to log session completion', e, stackTrace, _tag);
      // Don't rethrow - analytics failures shouldn't break the app
    }
  }

  /// Log review completion for FSRS/Review Analytics
  Future<void> logReviewCompletion({
    required String userId,
    required String wordId,
    required int rating,
    required Duration reviewTime,
  }) async {
    try {
      Logger.d('Logging review completion for word $wordId with rating $rating', _tag);
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('review_analytics')
          .add({
        'wordId': wordId,
        'rating': rating,
        'reviewTime': reviewTime.inMilliseconds,
        'completedAt': FieldValue.serverTimestamp(),
        'type': 'review_completion',
      });
      
      Logger.success('Review completion logged for word $wordId', _tag);
    } catch (e, stackTrace) {
      Logger.e('Failed to log review completion for word $wordId', e, stackTrace, _tag);
      // Don't rethrow - analytics failures shouldn't break the app
    }
  }
}

/// Cache data structure for weekly activity
class _CachedWeeklyData {
  final List<Map<String, dynamic>> data;
  final DateTime cachedAt;

  _CachedWeeklyData(this.data) : cachedAt = DateTime.now();

  bool get isExpired {
    return DateTime.now().difference(cachedAt) > StatisticsService._cacheExpiration;
  }
}
