// lib/services/migration_service_v2.dart
// Migration service for transitioning to optimized Firestore V2 structure

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'firestore_schema_v2.dart';

class MigrationServiceV2 {
  static const String _migrationBoxName = 'migration_status_v2';
  static const String _migrationKey = 'firestore_v2_migration';
  
  /// Check if user needs migration from old structure
  static Future<bool> needsMigration(String userId) async {
    try {
      // Check local migration status first
      final box = await Hive.openBox(_migrationBoxName);
      final migrationStatus = box.get('${_migrationKey}_$userId');
      
      if (migrationStatus == 'completed') {
        return false;
      }
      
      // Check if user has old data structure
      return await FirestoreSchemaV2.hasPublicWordsDependencies(userId);
    } catch (e) {
      print('Migration check error: $e');
      return false;
    }
  }
  
  /// Migrate user data from old structure to V2
  static Future<bool> migrateUserData(String userId) async {
    try {
      print('Starting migration for user: $userId');
      
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      
      // 1. Migrate learned words
      await _migrateLearnedWords(userId, batch);
      
      // 2. Migrate word progress (SRS data)
      await _migrateWordProgress(userId, batch);
      
      // 3. Migrate daily words history
      await _migrateDailyWords(userId, batch);
      
      // 4. Create/update user stats
      await _createUserStats(userId, batch);
      
      // Execute batch
      await batch.commit();
      
      // Mark migration as completed
      await _markMigrationCompleted(userId);
      
      print('Migration completed for user: $userId');
      return true;
      
    } catch (e) {
      print('Migration failed for user $userId: $e');
      return false;
    }
  }
  
  /// Migrate learned words from old structure
  static Future<void> _migrateLearnedWords(String userId, WriteBatch batch) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get learned words from old structure
      final learnedWordsSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('learned_words') // Old collection
          .get();
      
      for (final doc in learnedWordsSnapshot.docs) {
        final data = doc.data();
        final wordId = doc.id;
        
        // Create new learned word document
        final newDocRef = firestore.doc(
          FirestoreSchemaV2.getLearnedWordsPath(userId, wordId)
        );
        
        batch.set(newDocRef, FirestoreSchemaV2.createLearnedWord(
          wordId: wordId,
          learnedAt: (data['learnedAt'] as Timestamp?)?.toDate(),
        ));
      }
      
      print('Migrated ${learnedWordsSnapshot.docs.length} learned words');
    } catch (e) {
      print('Error migrating learned words: $e');
    }
  }
  
  /// Migrate word progress (SRS data) from old structure
  static Future<void> _migrateWordProgress(String userId, WriteBatch batch) async {
    try {
      final progressData = await FirestoreSchemaV2.getUserProgressForMigration(userId);
      
      for (final progress in progressData) {
        final wordId = progress['wordId'] as String;
        
        // Create new word progress document
        final newDocRef = FirebaseFirestore.instance.doc(
          FirestoreSchemaV2.getWordProgressPath(userId, wordId)
        );
        
        batch.set(newDocRef, FirestoreSchemaV2.createWordProgress(
          wordId: wordId,
          srsLevel: progress['srsLevel'] ?? 1,
          nextReview: (progress['nextReview'] as Timestamp?)?.toDate(),
          correctAnswers: progress['correctAnswers'] ?? 0,
          wrongAnswers: progress['wrongAnswers'] ?? 0,
          lastReviewed: (progress['lastReviewed'] as Timestamp?)?.toDate(),
          mastered: progress['mastered'] ?? false,
          streak: progress['streak'] ?? 0,
          confidence: (progress['confidence'] ?? 0.0).toDouble(),
          difficulty: (progress['difficulty'] ?? 5.0).toDouble(),
          stability: (progress['stability'] ?? 1.0).toDouble(),
        ));
      }
      
      print('Migrated ${progressData.length} word progress records');
    } catch (e) {
      print('Error migrating word progress: $e');
    }
  }
  
  /// Migrate daily words history from old structure
  static Future<void> _migrateDailyWords(String userId, WriteBatch batch) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get daily words from old structure
      final dailyWordsSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('daily_words') // Old collection
          .get();
      
      for (final doc in dailyWordsSnapshot.docs) {
        final data = doc.data();
        final date = doc.id;
        
        // Create new daily words document
        final newDocRef = firestore.doc(
          FirestoreSchemaV2.getDailyWordsPath(userId, date)
        );
        
        batch.set(newDocRef, FirestoreSchemaV2.createDailyWords(
          date: date,
          dailyWords: List<String>.from(data['dailyWords'] ?? []),
          extraWords: List<String>.from(data['extraWords'] ?? []),
          completedWords: List<String>.from(data['completedWords'] ?? []),
          hasWatchedAd: data['hasWatchedAd'] ?? false,
        ));
      }
      
      print('Migrated ${dailyWordsSnapshot.docs.length} daily word records');
    } catch (e) {
      print('Error migrating daily words: $e');
    }
  }
  
  /// Create user stats from existing data
  static Future<void> _createUserStats(String userId, WriteBatch batch) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Calculate stats from migrated data
      final learnedWordsCount = await _getLearnedWordsCount(userId);
      final progressStats = await _getProgressStats(userId);
      
      final userStatsRef = firestore.doc(
        FirestoreSchemaV2.getUserStatsPath(userId)
      );
      
      batch.set(userStatsRef, FirestoreSchemaV2.createUserStats(
        learnedWordsCount: learnedWordsCount,
        totalWordsStudied: progressStats['totalStudied'] ?? 0,
        totalCorrectAnswers: progressStats['totalCorrect'] ?? 0,
        totalWrongAnswers: progressStats['totalWrong'] ?? 0,
        accuracy: progressStats['accuracy'] ?? 0.0,
        lastActivityDate: DateTime.now(),
      ), SetOptions(merge: true));
      
      print('Created user stats');
    } catch (e) {
      print('Error creating user stats: $e');
    }
  }
  
  /// Get learned words count for stats
  static Future<int> _getLearnedWordsCount(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('learned_words')
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
  
  /// Get progress statistics for user stats
  static Future<Map<String, dynamic>> _getProgressStats(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('word_progress')
          .get();
      
      int totalCorrect = 0;
      int totalWrong = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalCorrect += (data['correctAnswers'] as int?) ?? 0;
        totalWrong += (data['wrongAnswers'] as int?) ?? 0;
      }
      
      final totalAnswers = totalCorrect + totalWrong;
      final accuracy = totalAnswers > 0 ? (totalCorrect / totalAnswers) : 0.0;
      
      return {
        'totalStudied': snapshot.docs.length,
        'totalCorrect': totalCorrect,
        'totalWrong': totalWrong,
        'accuracy': accuracy,
      };
    } catch (e) {
      return {
        'totalStudied': 0,
        'totalCorrect': 0,
        'totalWrong': 0,
        'accuracy': 0.0,
      };
    }
  }
  
  /// Mark migration as completed
  static Future<void> _markMigrationCompleted(String userId) async {
    try {
      final box = await Hive.openBox(_migrationBoxName);
      await box.put('${_migrationKey}_$userId', 'completed');
      await box.put('${_migrationKey}_${userId}_date', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error marking migration completed: $e');
    }
  }
  
  /// Get migration status for user
  static Future<String> getMigrationStatus(String userId) async {
    try {
      final box = await Hive.openBox(_migrationBoxName);
      return box.get('${_migrationKey}_$userId', defaultValue: 'not_started');
    } catch (e) {
      return 'error';
    }
  }
  
  /// Reset migration status (for testing)
  static Future<void> resetMigrationStatus(String userId) async {
    try {
      final box = await Hive.openBox(_migrationBoxName);
      await box.delete('${_migrationKey}_$userId');
      await box.delete('${_migrationKey}_${userId}_date');
    } catch (e) {
      print('Error resetting migration status: $e');
    }
  }
}