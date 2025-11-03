import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';
import 'level_service.dart';

/// Service for managing weekly XP tracking and automatic reset
class WeeklyXpService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Get the start of the current week (Sunday 00:00:00)
  static DateTime getWeekStart([DateTime? date]) {
    final now = date ?? DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    return DateTime(sunday.year, sunday.month, sunday.day);
  }
  
  /// Get the end of the current week (Saturday 23:59:59)
  static DateTime getWeekEnd([DateTime? date]) {
    final weekStart = getWeekStart(date);
    return weekStart.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
  }
  
  /// Check if weekly reset is needed for a user
  static Future<bool> needsWeeklyReset(String userId) async {
    try {
      final doc = await _firestore
          .collection('leaderboard_stats')
          .doc(userId)
          .get();
          
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      final lastWeeklyReset = data['lastWeeklyReset'] as Timestamp?;
      
      if (lastWeeklyReset == null) return true;
      
      final lastResetDate = lastWeeklyReset.toDate();
      final currentWeekStart = getWeekStart();
      
      // Reset needed if last reset was before current week
      return lastResetDate.isBefore(currentWeekStart);
    } catch (e) {
      Logger.e('[WEEKLY_XP] Error checking reset need for user $userId', e, null, 'WeeklyXpService');
      return false;
    }
  }
  
  /// Reset weekly XP for a user
  static Future<void> resetWeeklyXp(String userId) async {
    try {
      final docRef = _firestore.collection('leaderboard_stats').doc(userId);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        
        if (!doc.exists) return;
        
        final currentWeekStart = getWeekStart();
        
        transaction.update(docRef, {
          'weeklyXp': 0,
          'weeklyQuizzes': 0,
          'lastWeeklyReset': Timestamp.fromDate(currentWeekStart),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });
      
      Logger.i('[WEEKLY_XP] Reset completed for user $userId', 'WeeklyXpService');
    } catch (e) {
      Logger.e('[WEEKLY_XP] Error resetting weekly XP for user $userId', e, null, 'WeeklyXpService');
    }
  }
  
  /// Add XP to both total and weekly counters
  static Future<void> addXp(String userId, int amount) async {
    if (amount <= 0) return;
    
    try {
      final leaderboardRef = _firestore.collection('leaderboard_stats').doc(userId);
      final userRef = _firestore.collection('users').doc(userId);
      final summaryRef = userRef.collection('stats').doc('summary');
      final currentWeekStart = getWeekStart();
      
      await _firestore.runTransaction((transaction) async {
        final leaderboardDoc = await transaction.get(leaderboardRef);
        
        int currentTotalXp = 0;
        int currentWeeklyXp = 0;
        int currentHighestLevel = 1;
        Timestamp? lastWeeklyReset;
        
        if (leaderboardDoc.exists) {
          final data = leaderboardDoc.data()!;
          currentTotalXp = (data['totalXp'] as int?) ?? 0;
          currentWeeklyXp = (data['weeklyXp'] as int?) ?? 0;
          currentHighestLevel = (data['highestLevel'] as int?) ?? 1;
          lastWeeklyReset = data['lastWeeklyReset'] as Timestamp?;
        }
        
        final bool needsReset = lastWeeklyReset == null ||
            lastWeeklyReset.toDate().isBefore(currentWeekStart);
        
        final int newTotalXp = currentTotalXp + amount;
        final int newWeeklyXp = needsReset ? amount : currentWeeklyXp + amount;
        final levelData = LevelService.computeLevelData(newTotalXp);
        
        final leaderboardUpdates = <String, dynamic>{
          'userId': userId,
          'totalXp': newTotalXp,
          'weeklyXp': newWeeklyXp,
          'level': levelData.level,
          'highestLevel': levelData.level > currentHighestLevel
              ? levelData.level
              : currentHighestLevel,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        
        if (needsReset) {
          leaderboardUpdates['lastWeeklyReset'] =
              Timestamp.fromDate(currentWeekStart);
          leaderboardUpdates['weeklyQuizzes'] = 0;
        }
        
        transaction.set(leaderboardRef, leaderboardUpdates, SetOptions(merge: true));
        
        transaction.set(userRef, {
          'totalXp': FieldValue.increment(amount),
          'level': levelData.level,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        transaction.set(summaryRef, {
          'totalXp': FieldValue.increment(amount),
          'level': levelData.level,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        Logger.i('[WEEKLY_XP] Added $amount XP to user $userId (total: $newTotalXp, weekly: $newWeeklyXp, level: ${levelData.level}, reset: $needsReset)', 'WeeklyXpService');
      });
    } catch (e) {
      Logger.e('[WEEKLY_XP] Error adding XP for user $userId', e, null, 'WeeklyXpService');
      rethrow;
    }
  }
  
  /// Add quiz completion to both total and weekly counters
  static Future<void> addQuizCompletion(String userId) async {
    try {
      final leaderboardRef = _firestore.collection('leaderboard_stats').doc(userId);
      final userRef = _firestore.collection('users').doc(userId);
      final summaryRef = userRef.collection('stats').doc('summary');
      final currentWeekStart = getWeekStart();
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(leaderboardRef);
        
        if (!doc.exists) return;
        
        final data = doc.data()!;
        final currentTotalQuizzes = (data['quizzesCompleted'] as int?) ?? 0;
        final currentWeeklyQuizzes = (data['weeklyQuizzes'] as int?) ?? 0;
        
        // Check if weekly reset is needed
        final lastWeeklyReset = data['lastWeeklyReset'] as Timestamp?;
        final currentWeekStart = getWeekStart();
        bool needsReset = false;
        
        if (lastWeeklyReset == null || lastWeeklyReset.toDate().isBefore(currentWeekStart)) {
          needsReset = true;
        }
        
        final newWeeklyQuizzes = needsReset ? 1 : currentWeeklyQuizzes + 1;
        
        final updateData = <String, dynamic>{
          'quizzesCompleted': currentTotalQuizzes + 1,
          'weeklyQuizzes': newWeeklyQuizzes,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        
        if (needsReset) {
          updateData['lastWeeklyReset'] = Timestamp.fromDate(currentWeekStart);
          updateData['weeklyXp'] = 0; // Reset weekly XP too
        }
        
        transaction.update(leaderboardRef, updateData);
        
        transaction.set(userRef, {
          'totalQuizzesCompleted': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        transaction.set(summaryRef, {
          'totalQuizzesCompleted': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        Logger.i('[WEEKLY_XP] Added quiz completion for user $userId (total: ${currentTotalQuizzes + 1}, weekly: $newWeeklyQuizzes, reset: $needsReset)', 'WeeklyXpService');
      });
    } catch (e) {
      Logger.e('[WEEKLY_XP] Error adding quiz completion for user $userId', e, null, 'WeeklyXpService');
      rethrow;
    }
  }
  
  /// Get current week's leaderboard data
  static Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('leaderboard_stats')
          .orderBy('weeklyXp', descending: true)
          .limit(limit)
          .get();
          
      return snapshot.docs.map((doc) => {
        'userId': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      Logger.e('[WEEKLY_XP] Error fetching weekly leaderboard', e, null, 'WeeklyXpService');
      return [];
    }
  }
  
  /// Batch reset all users' weekly stats (for scheduled job)
  static Future<void> batchResetAllUsers() async {
    try {
      final currentWeekStart = getWeekStart();
      final batch = _firestore.batch();
      int batchCount = 0;
      
      // Query users who need reset
      final snapshot = await _firestore
          .collection('leaderboard_stats')
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lastWeeklyReset = data['lastWeeklyReset'] as Timestamp?;
        
        if (lastWeeklyReset == null || lastWeeklyReset.toDate().isBefore(currentWeekStart)) {
          batch.update(doc.reference, {
            'weeklyXp': 0,
            'weeklyQuizzes': 0,
            'lastWeeklyReset': Timestamp.fromDate(currentWeekStart),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          
          batchCount++;
          
          // Firestore batch limit is 500
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }
      
      if (batchCount > 0) {
        await batch.commit();
      }
      
      Logger.i('[WEEKLY_XP] Batch reset completed for $batchCount users', 'WeeklyXpService');
    } catch (e) {
      Logger.e('[WEEKLY_XP] Error in batch reset', e, null, 'WeeklyXpService');
    }
  }
}
