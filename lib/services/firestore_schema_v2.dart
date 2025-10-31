// lib/services/firestore_schema_v2.dart
// Optimized Firestore Schema - No public_words collection, user-focused structure

import 'package:cloud_firestore/cloud_firestore.dart';

/// Optimized Firestore Schema V2
/// Removes public_words collection, focuses on user progress and daily selections
/// Uses 1kwords.json as the single source of truth for word content
class FirestoreSchemaV2 {
  
  // ===========================================
  // LEARNED WORDS COLLECTION
  // ===========================================
  
  static const String learnedWordsSubcollection = 'learned_words';
  
  /// Create learned word document (minimal data)
  static Map<String, dynamic> createLearnedWord({
    required String wordId,
    DateTime? learnedAt,
  }) {
    return {
      'wordId': wordId.toLowerCase(), // Normalize for consistency
      'learnedAt': learnedAt != null 
          ? Timestamp.fromDate(learnedAt) 
          : FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Get learned words path
  static String getLearnedWordsPath(String userId, String wordId) {
    final safeUserId = _sanitizeDocumentId(userId);
    final safeWordId = _sanitizeDocumentId(wordId.toLowerCase());
    return 'users/$safeUserId/$learnedWordsSubcollection/$safeWordId';
  }
  
  // ===========================================
  // DAILY WORDS COLLECTION
  // ===========================================
  
  static const String dailyWordsSubcollection = 'daily_words';
  
  /// Create daily words document
  static Map<String, dynamic> createDailyWords({
    required String date,
    required List<String> dailyWords,
    List<String> extraWords = const [],
    List<String> completedWords = const [],
    bool hasWatchedAd = false,
  }) {
    return {
      'date': date,
      'dailyWords': dailyWords.map((w) => w.toLowerCase()).toList(), // Normalize
      'extraWords': extraWords.map((w) => w.toLowerCase()).toList(),
      'completedWords': completedWords.map((w) => w.toLowerCase()).toList(),
      'hasWatchedAd': hasWatchedAd,
      'generatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Get daily words path
  static String getDailyWordsPath(String userId, String date) {
    final safeUserId = _sanitizeDocumentId(userId);
    return 'users/$safeUserId/$dailyWordsSubcollection/$date';
  }
  
  // ===========================================
  // WORD PROGRESS COLLECTION (SRS)
  // ===========================================
  
  static const String wordProgressSubcollection = 'word_progress';
  
  /// Create word progress document for SRS
  static Map<String, dynamic> createWordProgress({
    required String wordId,
    int srsLevel = 1,
    DateTime? nextReview,
    int correctAnswers = 0,
    int wrongAnswers = 0,
    DateTime? lastReviewed,
    bool mastered = false,
    int streak = 0,
    double confidence = 0.0,
    double difficulty = 5.0,
    double stability = 1.0,
  }) {
    return {
      'wordId': wordId.toLowerCase(),
      'srsLevel': srsLevel,
      'nextReview': nextReview != null ? Timestamp.fromDate(nextReview) : null,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'lastReviewed': lastReviewed != null ? Timestamp.fromDate(lastReviewed) : null,
      'mastered': mastered,
      'streak': streak,
      'confidence': confidence,
      'difficulty': difficulty, // FSRS-Lite parameter
      'stability': stability,   // FSRS-Lite parameter
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Get word progress path
  static String getWordProgressPath(String userId, String wordId) {
    final safeUserId = _sanitizeDocumentId(userId);
    final safeWordId = _sanitizeDocumentId(wordId.toLowerCase());
    return 'users/$safeUserId/$wordProgressSubcollection/$safeWordId';
  }
  
  // ===========================================
  // USER STATS COLLECTION
  // ===========================================
  
  /// Create user stats document
  static Map<String, dynamic> createUserStats({
    int xp = 0,
    int level = 1,
    int streak = 0,
    int learnedWordsCount = 0,
    int totalWordsStudied = 0,
    int totalQuizzesCompleted = 0,
    int totalCorrectAnswers = 0,
    int totalWrongAnswers = 0,
    double accuracy = 0.0,
    DateTime? lastActivityDate,
    Map<String, int> dailyActivity = const {},
    Map<String, int> weeklyActivity = const {},
    Map<String, int> monthlyActivity = const {},
  }) {
    return {
      'xp': xp,
      'level': level,
      'streak': streak,
      'learnedWordsCount': learnedWordsCount,
      'totalWordsStudied': totalWordsStudied,
      'totalQuizzesCompleted': totalQuizzesCompleted,
      'totalCorrectAnswers': totalCorrectAnswers,
      'totalWrongAnswers': totalWrongAnswers,
      'accuracy': accuracy,
      'lastActivityDate': lastActivityDate != null 
          ? Timestamp.fromDate(lastActivityDate) 
          : null,
      'dailyActivity': dailyActivity,
      'weeklyActivity': weeklyActivity,
      'monthlyActivity': monthlyActivity,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
  
  /// Get user stats path
  static String getUserStatsPath(String userId) {
    final safeUserId = _sanitizeDocumentId(userId);
    return 'users/$safeUserId';
  }
  
  // ===========================================
  // USER ACTIVITY COLLECTION
  // ===========================================
  
  static const String userActivitySubcollection = 'activity';
  
  // Activity types
  static const String activityTypeQuizCompleted = 'quiz_completed';
  static const String activityTypeWordLearned = 'word_learned';
  static const String activityTypeStreakUpdated = 'streak_updated';
  static const String activityTypeLevelUp = 'level_up';
  static const String activityTypeDailyWordsCompleted = 'daily_words_completed';
  
  /// Create user activity document
  static Map<String, dynamic> createUserActivity({
    required String type,
    int xpEarned = 0,
    int learnedWordsCount = 0,
    String? quizType,
    int correctAnswers = 0,
    int totalQuestions = 0,
    String? wordId,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'type': type,
      'xpEarned': xpEarned,
      'learnedWordsCount': learnedWordsCount,
      'quizType': quizType,
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'wordId': wordId?.toLowerCase(),
      'metadata': metadata ?? {},
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
  
  /// Get user activity path
  static String getUserActivityPath(String userId, String activityId) {
    final safeUserId = _sanitizeDocumentId(userId);
    return 'users/$safeUserId/$userActivitySubcollection/$activityId';
  }
  
  // ===========================================
  // LEADERBOARD COLLECTION (OPTIONAL)
  // ===========================================
  
  static const String leaderboardCollection = 'leaderboard_stats';
  
  /// Create leaderboard stats document
  static Map<String, dynamic> createLeaderboardStats({
    required String userId,
    required String displayName,
    int wordsLearned = 0,
    int xp = 0,
    int level = 1,
    int streak = 0,
    DateTime? lastUpdated,
  }) {
    return {
      'userId': userId,
      'displayName': displayName,
      'wordsLearned': wordsLearned,
      'xp': xp,
      'level': level,
      'streak': streak,
      'lastUpdated': lastUpdated != null 
          ? Timestamp.fromDate(lastUpdated) 
          : FieldValue.serverTimestamp(),
    };
  }
  
  // ===========================================
  // MIGRATION HELPERS
  // ===========================================
  
  /// Migration helper: Check if user has old public_words dependencies
  static Future<bool> hasPublicWordsDependencies(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Check if user has any word_progress documents
      final progressSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection(wordProgressSubcollection)
          .limit(1)
          .get();
      
      return progressSnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Migration helper: Get user's current progress for migration
  static Future<List<Map<String, dynamic>>> getUserProgressForMigration(String userId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      final snapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('word_progress') // Old collection name
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['wordId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }
  
  // ===========================================
  // UTILITY METHODS
  // ===========================================
  
  /// Sanitize document ID to be Firestore-safe
  static String _sanitizeDocumentId(String id) {
    // Remove invalid characters and ensure valid length
    String sanitized = id
        .replaceAll(RegExp(r'[/\\]'), '_')
        .replaceAll(RegExp(r'[^\w\-._~]'), '_')
        .toLowerCase();
    
    // Ensure it's not empty and not too long
    if (sanitized.isEmpty) sanitized = 'unknown';
    if (sanitized.length > 1500) sanitized = sanitized.substring(0, 1500);
    
    return sanitized;
  }
  
  /// Validate document path
  static void _validateDocumentPath(String path) {
    if (path.split('/').length % 2 != 0) {
      throw ArgumentError('Invalid document path: $path');
    }
  }
  
  /// Get current date string for daily operations
  static String getCurrentDateString() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  /// Get date string from DateTime
  static String getDateString(DateTime date) {
    final utcDate = date.toUtc();
    return '${utcDate.year}-${utcDate.month.toString().padLeft(2, '0')}-${utcDate.day.toString().padLeft(2, '0')}';
  }
  
  // ===========================================
  // BATCH OPERATIONS
  // ===========================================
  
  /// Create batch operation for multiple learned words
  static WriteBatch createLearnedWordsBatch(
    FirebaseFirestore firestore,
    String userId,
    List<String> wordIds,
  ) {
    final batch = firestore.batch();
    
    for (final wordId in wordIds) {
      final docRef = firestore.doc(getLearnedWordsPath(userId, wordId));
      batch.set(docRef, createLearnedWord(wordId: wordId));
    }
    
    return batch;
  }
  
  /// Create batch operation for word progress updates
  static WriteBatch createWordProgressBatch(
    FirebaseFirestore firestore,
    String userId,
    Map<String, Map<String, dynamic>> progressUpdates,
  ) {
    final batch = firestore.batch();
    
    progressUpdates.forEach((wordId, progress) {
      final docRef = firestore.doc(getWordProgressPath(userId, wordId));
      batch.set(docRef, progress, SetOptions(merge: true));
    });
    
    return batch;
  }
  
  // ===========================================
  // QUERY HELPERS
  // ===========================================
  
  /// Get learned words query
  static Query<Map<String, dynamic>> getLearnedWordsQuery(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_sanitizeDocumentId(userId))
        .collection(learnedWordsSubcollection);
  }
  
  /// Get words for review query
  static Query<Map<String, dynamic>> getWordsForReviewQuery(String userId, DateTime beforeDate) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_sanitizeDocumentId(userId))
        .collection(wordProgressSubcollection)
        .where('nextReview', isLessThanOrEqualTo: Timestamp.fromDate(beforeDate))
        .where('mastered', isEqualTo: false)
        .orderBy('nextReview');
  }
  
  /// Get daily words query
  static Query<Map<String, dynamic>> getDailyWordsQuery(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_sanitizeDocumentId(userId))
        .collection(dailyWordsSubcollection)
        .orderBy('date', descending: true);
  }
}