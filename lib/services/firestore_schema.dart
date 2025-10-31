// lib/services/firestore_schema.dart
// Firestore Schema Definitions for WordFlow Migration

import 'package:cloud_firestore/cloud_firestore.dart';


class FirestoreSchema {

  static const String publicWordsCollection = 'public_words';


  static Map<String, dynamic> createPublicWord({
    required String wordId,
    required String word,
    required String meaning,
    required String tr,
    required String exampleSentence,
    String pronunciation = '',
    String partOfSpeech = '',
    String difficulty = 'beginner',
    List<String> tags = const [],
    bool isCustom = false,
    String? createdBy,
  }) {
    return {
      'wordId': wordId,
      'word': word,
      'meaning': meaning,
      'tr': tr,
      'exampleSentence': exampleSentence,
      'pronunciation': pronunciation,
      'partOfSpeech': partOfSpeech,
      'difficulty': difficulty,
      'tags': tags,
      'isCustom': isCustom,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'version': 1, // For future schema migrations
    };
  }

  // ===========================================
  // USER WORD PROGRESS COLLECTION
  // ===========================================

 
  static const String userWordProgressSubcollection = 'word_progress';


  static Map<String, dynamic> createUserWordProgress({
    required String wordId,
    int srsLevel = 0,
    DateTime? nextReview,
    int correctAnswers = 0,
    int wrongAnswers = 0,
    DateTime? lastReviewed,
    bool mastered = false,
    int streak = 0,
    double confidence = 0.0,
  }) {
    return {
      'wordId': wordId,
      'srsLevel': srsLevel,
      'nextReview': nextReview != null ? Timestamp.fromDate(nextReview) : null,
      'correctAnswers': correctAnswers,
      'wrongAnswers': wrongAnswers,
      'lastReviewed':
          lastReviewed != null ? Timestamp.fromDate(lastReviewed) : null,
      'mastered': mastered,
      'streak': streak,
      'confidence': confidence,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ===========================================
  // USER ACTIVITY COLLECTION
  // ===========================================

  
  static const String userActivitySubcollection = 'activity';

 
  static const String activityTypeQuizCompleted = 'quiz_completed';
  static const String activityTypeWordLearned = 'word_learned';
  static const String activityTypeStreakUpdated = 'streak_updated';
  static const String activityTypeLevelUp = 'level_up';
  static const String activityTypeCustomWordAdded = 'custom_word_added';

  // ===========================================
  // LEARNED WORDS COLLECTION
  // ===========================================

  
  static const String learnedWordsSubcollection = 'learned_words';

 
  static Map<String, dynamic> createLearnedWord({
    required String wordId,
    required String word,
    DateTime? learnedAt,
  }) {
    return {
      'wordId': wordId,
      'word': word,
      'learnedAt': learnedAt != null 
          ? Timestamp.fromDate(learnedAt) 
          : FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ===========================================
  // DAILY WORDS COLLECTION
  // ===========================================


  static const String dailyWordsSubcollection = 'daily_words';

  static Map<String, dynamic> createDailyWords({
    required String date,
    required List<String> dailyWords,
    List<String> extraWords = const [],
    List<String> completedWords = const [],
    bool hasWatchedAd = false,
  }) {
    return {
      'date': date,
      'dailyWords': dailyWords,
      'extraWords': extraWords,
      'completedWords': completedWords,
      'hasWatchedAd': hasWatchedAd,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

 
  static String getDailyWordsPath(String userId, String date) {
    final safeUserId = _sanitizeDocumentId(userId);
    final path = 'users/$safeUserId/$dailyWordsSubcollection/$date';
    _validateDocumentPath(path);
    return path;
  }

  
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
      'wordId': wordId,
      'metadata': metadata ?? {},
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  // ===========================================
  // USER STATS COLLECTION (ENHANCED)
  // ===========================================

 
  static Map<String, dynamic> createUserStats({
    required int xp,
    required int level,
    required int streak,
    required int learnedWordsCount,
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
      'lastActivityDate':
          lastActivityDate != null
              ? Timestamp.fromDate(lastActivityDate)
              : null,
      'dailyActivity': dailyActivity,
      'weeklyActivity': weeklyActivity,
      'monthlyActivity': monthlyActivity,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ===========================================
  // MIGRATION TRACKING
  // ===========================================

 
  static const String migrationStatusDocument = 'migration_status';
  static const String userDataCollection = 'user_data';

 
  static Map<String, dynamic> createMigrationStatus({
    required bool isCompleted,
    required String version,
    DateTime? completedAt,
    Map<String, dynamic>? errors,
    int totalWordsMigrated = 0,
    int totalProgressMigrated = 0,
    int totalActivitiesMigrated = 0,
  }) {
    return {
      'isCompleted': isCompleted,
      'version': version,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt) : null,
      'errors': errors ?? {},
      'totalWordsMigrated': totalWordsMigrated,
      'totalProgressMigrated': totalProgressMigrated,
      'totalActivitiesMigrated': totalActivitiesMigrated,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ===========================================
  // HELPER METHODS
  // ===========================================


  static String _sanitizeDocumentId(String id) {
    if (id.isEmpty) {
      throw ArgumentError('Document ID cannot be empty');
    }
   
    final sanitized = id.replaceAll(RegExp(r'[\.\*\$\#\[\]\/\\]'), '_');
    if (sanitized.isEmpty) {
      throw ArgumentError(
        'Document ID cannot consist only of invalid characters: $id',
      );
    }
    return sanitized;
  }

  
  static void _validateDocumentPath(String path) {
    if (path.contains('..') ||
        path.contains('*') ||
        path.contains('[') ||
        path.contains(']') ||
        path.contains(r'$') ||
        path.contains('#')) {
      throw ArgumentError('Invalid document path detected: $path');
    }
  }

 
  static String getUserWordProgressPath(String userId, String wordId) {
    final safeUserId = _sanitizeDocumentId(userId);
    final safeWordId = _sanitizeDocumentId(wordId);
    final path = 'users/$safeUserId/$userWordProgressSubcollection/$safeWordId';
    _validateDocumentPath(path);
    return path;
  }

 
  static String getUserActivityPath(String userId, String timestamp) {
    final safeUserId = _sanitizeDocumentId(userId);
    final safeTimestamp = _sanitizeDocumentId(timestamp);
    final path = 'users/$safeUserId/$userActivitySubcollection/$safeTimestamp';
    _validateDocumentPath(path);
    return path;
  }

  
  static String getPublicWordPath(String wordId) {
    final safeWordId = _sanitizeDocumentId(wordId);
    final path = '$publicWordsCollection/$safeWordId';
    _validateDocumentPath(path);
    return path;
  }

  
  static String getUserStatsPath(String userId) {
    final safeUserId = _sanitizeDocumentId(userId);
    final path = 'users/$safeUserId';
    _validateDocumentPath(path);
    return path;
  }

 
  static String getMigrationStatusPath(String userId) {
    final safeUserId = _sanitizeDocumentId(userId);
    final path =
        'users/$safeUserId/$userDataCollection/$migrationStatusDocument';
    _validateDocumentPath(path);
    return path;
  }

  // ===========================================
  // LEADERBOARD COLLECTION
  // ===========================================

  
  static const String leaderboardStatsCollection = 'leaderboard_stats';

  static Map<String, dynamic> createLeaderboardStats({
    required String userId,
    required String displayName,
    String? photoURL,
    int level = 1, // using standardized level field
    int totalXp = 0,
    int weeklyXp = 0,
    int currentStreak = 0,
    int longestStreak = 0,
    int quizzesCompleted = 0,
    int wordsLearned = 0,
    int rank = 0,
    int? previousRank,
    DateTime? weekResetDate,
  }) {
    return {
      'userId': userId,
      'displayName': displayName,
      'photoURL': photoURL,
      'level': level, // using standardized level field
      'totalXp': totalXp,
      'weeklyXp': weeklyXp,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'quizzesCompleted': quizzesCompleted,
      'wordsLearned': wordsLearned,
      'rank': rank,
      'previousRank': previousRank,
      'weekResetDate':
          weekResetDate != null
              ? Timestamp.fromDate(weekResetDate)
              : FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

 
  static String getLeaderboardStatsPath(String userId) {
    final safeUserId = _sanitizeDocumentId(userId);
    return '$leaderboardStatsCollection/$safeUserId';
  }

  // ===========================================
  // BATCH OPERATIONS
  // ===========================================

 
  static const int migrationBatchSize = 100;

 
  static const int maxRetryAttempts = 3;

 
  static const String currentMigrationVersion = '1.0.0';
}
 