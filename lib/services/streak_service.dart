import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

/// Centralized streak management service
/// Provides single source of truth for streak data across the app
class StreakService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Ensure initial default values for new users
  /// Sets currentStreak=1, longestStreak=1, lastActivityDate=serverTimestamp
  static Future<void> ensureInitialDefaults(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      
      // Check if defaults need to be set
      final currentStreak = userData?['currentStreak'] as int?;
      final longestStreak = userData?['longestStreak'] as int?;
      final lastActivityDate = userData?['lastActivityDate'] as Timestamp?;
      
      final batch = _firestore.batch();
      bool needsUpdate = false;
      
      final updates = <String, dynamic>{};
      
      // Set currentStreak to 1 if null or 0
      if (currentStreak == null || currentStreak == 0) {
        updates['currentStreak'] = 1;
        needsUpdate = true;
      }
      
      // Set longestStreak to max(1, existing) if null or less than 1
      if (longestStreak == null || longestStreak < 1) {
        updates['longestStreak'] = 1;
        needsUpdate = true;
      }
      
      // Set lastActivityDate if null
      if (lastActivityDate == null) {
        updates['lastActivityDate'] = FieldValue.serverTimestamp();
        needsUpdate = true;
      }
      
      if (needsUpdate) {
        updates['lastUpdated'] = FieldValue.serverTimestamp();
        
        // Update users collection
        batch.update(_firestore.collection('users').doc(uid), updates);
        
        // Also update leaderboard_stats for consistency
        final leaderboardUpdates = <String, dynamic>{
          'currentStreak': updates['currentStreak'] ?? currentStreak ?? 1,
          'longestStreak': updates['longestStreak'] ?? longestStreak ?? 1,
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        
        batch.update(_firestore.collection('leaderboard_stats').doc(uid), leaderboardUpdates);
        
        await batch.commit();
        
        Logger.i('[STREAK] Initial defaults set for user $uid: currentStreak=${updates['currentStreak']}, longestStreak=${updates['longestStreak']}', 'StreakService');
      }
    } catch (e) {
      Logger.e('[STREAK] Failed to ensure initial defaults for user $uid', e, null, 'StreakService');
      rethrow;
    }
  }
  
  /// Get today's date key in UTC (YYYY-MM-DD format)
  static String getTodayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  /// Check if the given timestamp represents a different day than today
  static bool isNewDay(Timestamp? lastActivityDate) {
    if (lastActivityDate == null) return true;
    
    final lastDate = lastActivityDate.toDate().toUtc();
    final today = DateTime.now().toUtc();
    
    // Compare date components only (ignore time)
    return lastDate.year != today.year || 
           lastDate.month != today.month || 
           lastDate.day != today.day;
  }
  
  /// Increment streak if it's a new day
  /// Returns true if streak was incremented, false if already updated today
  static Future<bool> incrementIfNewDay(String uid) async {
    try {
      // Get current user data
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      
      if (userData == null) {
        Logger.w('[STREAK] User document not found for uid: $uid', 'StreakService');
        return false;
      }
      
      final lastActivityDate = userData['lastActivityDate'] as Timestamp?;
      
      // Check if it's a new day
      if (!isNewDay(lastActivityDate)) {
        Logger.i('[STREAK] Streak already updated today for user $uid', 'StreakService');
        return false;
      }
      
      // Calculate new streak values
      final currentStreak = (userData['currentStreak'] as int? ?? 0) + 1;
      final existingLongestStreak = userData['longestStreak'] as int? ?? 0;
      final longestStreak = currentStreak > existingLongestStreak ? currentStreak : existingLongestStreak;
      
      // Prepare batch update
      final batch = _firestore.batch();
      final timestamp = FieldValue.serverTimestamp();
      
      final updates = {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActivityDate': timestamp,
        'lastUpdated': timestamp,
      };
      
      // Update users collection
      batch.update(_firestore.collection('users').doc(uid), updates);
      
      // Update leaderboard_stats collection for consistency
      batch.update(_firestore.collection('leaderboard_stats').doc(uid), {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastUpdated': timestamp,
      });
      
      await batch.commit();
      
      Logger.i('[STREAK] Streak incremented for user $uid: $currentStreak (longest: $longestStreak)', 'StreakService');
      return true;
    } catch (e) {
      Logger.e('[STREAK] Failed to increment streak for user $uid', e, null, 'StreakService');
      rethrow;
    }
  }
  
  /// Migration helper for existing users
  /// Sets currentStreak=1 if 0, longestStreak=max(1, existing), lastActivityDate=now if null
  static Future<void> migrateExistingUser(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      
      if (userData == null) {
        Logger.w('[STREAK] User document not found for migration: $uid', 'StreakService');
        return;
      }
      
      final currentStreak = userData['currentStreak'] as int?;
      final longestStreak = userData['longestStreak'] as int?;
      final lastActivityDate = userData['lastActivityDate'] as Timestamp?;
      
      final batch = _firestore.batch();
      bool needsUpdate = false;
      final updates = <String, dynamic>{};
      
      // Fix currentStreak if 0
      if (currentStreak == 0) {
        updates['currentStreak'] = 1;
        needsUpdate = true;
      }
      
      // Fix longestStreak if less than 1
      if (longestStreak == null || longestStreak < 1) {
        updates['longestStreak'] = (longestStreak ?? 0) < 1 ? 1 : longestStreak;
        needsUpdate = true;
      }
      
      // Set lastActivityDate if null
      if (lastActivityDate == null) {
        updates['lastActivityDate'] = FieldValue.serverTimestamp();
        needsUpdate = true;
      }
      
      if (needsUpdate) {
        updates['lastUpdated'] = FieldValue.serverTimestamp();
        
        // Update users collection
        batch.update(_firestore.collection('users').doc(uid), updates);
        
        // Update leaderboard_stats collection
        final leaderboardUpdates = <String, dynamic>{
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        
        if (updates.containsKey('currentStreak')) {
          leaderboardUpdates['currentStreak'] = updates['currentStreak'];
        }
        if (updates.containsKey('longestStreak')) {
          leaderboardUpdates['longestStreak'] = updates['longestStreak'];
        }
        
        batch.update(_firestore.collection('leaderboard_stats').doc(uid), leaderboardUpdates);
        
        await batch.commit();
        
        Logger.i('[STREAK] Migration completed for user $uid: ${updates.toString()}', 'StreakService');
      } else {
        Logger.i('[STREAK] No migration needed for user $uid', 'StreakService');
      }
    } catch (e) {
      Logger.e('[STREAK] Migration failed for user $uid', e, null, 'StreakService');
      rethrow;
    }
  }
  
  /// Check if user needs streak reset due to missed days
  /// This is called during app initialization to handle missed days
  static Future<void> checkAndResetStreakIfNeeded(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data();
      
      if (userData == null) return;
      
      final lastActivityDate = userData['lastActivityDate'] as Timestamp?;
      final currentStreak = userData['currentStreak'] as int? ?? 0;
      
      if (lastActivityDate == null || currentStreak == 0) return;
      
      final lastDate = lastActivityDate.toDate().toUtc();
      final today = DateTime.now().toUtc();
      final daysDifference = today.difference(lastDate).inDays;
      
      // Reset streak if more than 1 day has passed
      if (daysDifference > 1) {
        final batch = _firestore.batch();
        final timestamp = FieldValue.serverTimestamp();
        
        final updates = {
          'currentStreak': 0,
          'lastUpdated': timestamp,
        };
        
        // Update users collection
        batch.update(_firestore.collection('users').doc(uid), updates);
        
        // Update leaderboard_stats collection
        batch.update(_firestore.collection('leaderboard_stats').doc(uid), {
          'currentStreak': 0,
          'lastUpdated': timestamp,
        });
        
        await batch.commit();
        
        Logger.i('[STREAK] Streak reset for user $uid due to $daysDifference days gap', 'StreakService');
      }
    } catch (e) {
      Logger.e('[STREAK] Failed to check/reset streak for user $uid', e, null, 'StreakService');
    }
  }
}