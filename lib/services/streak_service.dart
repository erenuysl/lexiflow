import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

/// Centralized streak management service
/// Provides single source of truth for streak data across the app
class StreakService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static Future<void> _syncStreakData(
    String uid, {
    required Map<String, dynamic> userUpdates,
    required Map<String, dynamic> leaderboardUpdates,
    Map<String, dynamic>? summaryUpdates,
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final summaryRef = userRef.collection('stats').doc('summary');
    final leaderboardRef = _firestore.collection('leaderboard_stats').doc(uid);

    final timestamp = FieldValue.serverTimestamp();

    final mergedUser = Map<String, dynamic>.from(userUpdates);
    mergedUser.putIfAbsent('lastUpdated', () => timestamp);

    final mergedLeaderboard = Map<String, dynamic>.from(leaderboardUpdates);
    mergedLeaderboard.putIfAbsent('lastUpdated', () => timestamp);

    final mergedSummary = <String, dynamic>{
      if (summaryUpdates != null) ...summaryUpdates,
      'updatedAt': timestamp,
    };

    await _firestore.runTransaction((transaction) async {
      transaction.set(userRef, mergedUser, SetOptions(merge: true));
      transaction.set(summaryRef, mergedSummary, SetOptions(merge: true));
      transaction.set(leaderboardRef, mergedLeaderboard, SetOptions(merge: true));
    });
  }
  
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
        final resolvedCurrent = updates['currentStreak'] ?? currentStreak ?? 1;
        final resolvedLongest = updates['longestStreak'] ?? longestStreak ?? 1;

        final userUpdates = Map<String, dynamic>.from(updates);
        userUpdates['currentStreak'] = resolvedCurrent;
        userUpdates['longestStreak'] = resolvedLongest;
        userUpdates.putIfAbsent('lastUpdated', () => FieldValue.serverTimestamp());

        await _syncStreakData(
          uid,
          userUpdates: userUpdates,
          leaderboardUpdates: {
            'currentStreak': resolvedCurrent,
            'longestStreak': resolvedLongest,
          },
          summaryUpdates: {
            'currentStreak': resolvedCurrent,
            'longestStreak': resolvedLongest,
          },
        );

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
      
      final timestamp = FieldValue.serverTimestamp();

      await _syncStreakData(
        uid,
        userUpdates: {
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'lastActivityDate': timestamp,
        },
        leaderboardUpdates: {
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
        },
        summaryUpdates: {
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'lastActivityDate': timestamp,
        },
      );
      
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
        final resolvedCurrent = updates.containsKey('currentStreak')
            ? updates['currentStreak'] as int
            : currentStreak ?? 0;
        final resolvedLongest = updates.containsKey('longestStreak')
            ? updates['longestStreak'] as int
            : longestStreak ?? resolvedCurrent;

        final userUpdates = Map<String, dynamic>.from(updates);
        userUpdates['currentStreak'] = resolvedCurrent;
        userUpdates['longestStreak'] = resolvedLongest;
        userUpdates.putIfAbsent('lastUpdated', () => FieldValue.serverTimestamp());

        final summaryUpdates = <String, dynamic>{
          'currentStreak': resolvedCurrent,
          'longestStreak': resolvedLongest,
        };
        if (updates.containsKey('lastActivityDate')) {
          summaryUpdates['lastActivityDate'] = updates['lastActivityDate'];
        }

        await _syncStreakData(
          uid,
          userUpdates: userUpdates,
          leaderboardUpdates: {
            'currentStreak': resolvedCurrent,
            'longestStreak': resolvedLongest,
          },
          summaryUpdates: summaryUpdates,
        );
        
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
        await _syncStreakData(
          uid,
          userUpdates: {
            'currentStreak': 0,
          },
          leaderboardUpdates: {
            'currentStreak': 0,
          },
          summaryUpdates: {
            'currentStreak': 0,
          },
        );
        
        Logger.i('[STREAK] Streak reset for user $uid due to $daysDifference days gap', 'StreakService');
      }
    } catch (e) {
      Logger.e('[STREAK] Failed to check/reset streak for user $uid', e, null, 'StreakService');
    }
  }
}
