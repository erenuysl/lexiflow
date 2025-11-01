// lib/utils/streak_migration_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

class StreakMigrationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Migrates existing users to have default streak values if they don't exist
  static Future<void> migrateUserStreakData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final userStatsRef = _firestore.collection('user_stats').doc(user.uid);
      final leaderboardRef = _firestore.collection('leaderboard_stats').doc(user.uid);
      
      // Check if user stats document exists and needs migration
      final userStatsDoc = await userStatsRef.get();
      if (userStatsDoc.exists) {
        final data = userStatsDoc.data()!;
        
        // Check if streak fields are missing
        if (!data.containsKey('currentStreak') || !data.containsKey('longestStreak') || !data.containsKey('lastActivityDate')) {
          await userStatsRef.update({
            'currentStreak': data['currentStreak'] ?? 0,
            'longestStreak': data['longestStreak'] ?? 0,
            'lastActivityDate': data['lastActivityDate'] ?? FieldValue.serverTimestamp(),
          });
          print('✅ Migrated user_stats streak data for user: ${user.uid}');
        }
      }
      
      // Check if leaderboard stats document exists and needs migration
      final leaderboardDoc = await leaderboardRef.get();
      if (leaderboardDoc.exists) {
        final data = leaderboardDoc.data()!;
        
        // Check if streak fields are missing
        if (!data.containsKey('currentStreak') || !data.containsKey('longestStreak')) {
          await leaderboardRef.update({
            'currentStreak': data['currentStreak'] ?? 0,
            'longestStreak': data['longestStreak'] ?? 0,
          });
          print('✅ Migrated leaderboard_stats streak data for user: ${user.uid}');
        }
      }
      
    } catch (e) {
      print('❌ Error during streak migration: $e');
    }
  }
  
  /// Initializes streak data for new users
  static Future<void> initializeStreakForNewUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final sessionService = SessionService();
      final userStatsRef = _firestore.collection('user_stats').doc(user.uid);
      final leaderboardRef = _firestore.collection('leaderboard_stats').doc(user.uid);
      
      // Initialize user_stats with streak data
      await userStatsRef.set({
        'currentStreak': 0,
        'longestStreak': 0,
        'lastActivityDate': FieldValue.serverTimestamp(),
        'level': sessionService.level,
        'totalXp': sessionService.totalXp,
        'learnedWordsCount': sessionService.learnedWordsCount,
        'quizzesCompleted': sessionService.totalQuizzesTaken,
      }, SetOptions(merge: true));
      
      // Initialize leaderboard_stats with streak data
      await leaderboardRef.set({
        'currentStreak': 0,
        'longestStreak': 0,
        'level': sessionService.level,
        'totalXp': sessionService.totalXp,
        'learnedWordsCount': sessionService.learnedWordsCount,
        'quizzesCompleted': sessionService.totalQuizzesTaken,
        'weeklyQuizzes': 0,
        'highestLevel': sessionService.level,
      }, SetOptions(merge: true));
      
      print('✅ Initialized streak data for new user: ${user.uid}');
      
    } catch (e) {
      print('❌ Error initializing streak for new user: $e');
    }
  }
}