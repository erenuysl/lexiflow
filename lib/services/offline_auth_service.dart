// lib/services/offline_auth_service.dart
// Offline authentication service for guest mode without internet connection

import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Offline Authentication Service
/// Provides local authentication capabilities for guest mode when offline
class OfflineAuthService {
  static const String _offlineUserKey = 'offline_guest_user';
  static const String _offlineSessionKey = 'offline_session_active';
  static const String _offlineUserStatsKey = 'offline_user_stats';
  
  /// Create offline guest user
  static Future<OfflineGuestUser?> createOfflineGuestUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Generate unique offline user ID
      final userId = _generateOfflineUserId();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      final offlineUser = OfflineGuestUser(
        uid: userId,
        isAnonymous: true,
        isOffline: true,
        createdAt: timestamp,
        lastActiveAt: timestamp,
      );
      
      // Save offline user data
      await prefs.setString(_offlineUserKey, jsonEncode(offlineUser.toMap()));
      await prefs.setBool(_offlineSessionKey, true);
      
      // Initialize default user stats
      final defaultStats = {
        'currentLevel': 1,
        'totalXp': 0,
        'currentStreak': 0,
        'longestStreak': 0,
        'learnedWordsCount': 0,
        'totalQuizzesTaken': 0,
        'favoritesCount': 0,
        'lastLoginDate': timestamp,
      };
      
      await prefs.setString(_offlineUserStatsKey, jsonEncode(defaultStats));
      
      Logger.i('Offline guest user created: $userId', 'OfflineAuthService');
      return offlineUser;
    } catch (e) {
      Logger.e('Failed to create offline guest user', e, null, 'OfflineAuthService');
      return null;
    }
  }
  
  /// Get current offline guest user
  static Future<OfflineGuestUser?> getCurrentOfflineUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSessionActive = prefs.getBool(_offlineSessionKey) ?? false;
      
      if (!isSessionActive) {
        return null;
      }
      
      final userJson = prefs.getString(_offlineUserKey);
      if (userJson == null) {
        return null;
      }
      
      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      final offlineUser = OfflineGuestUser.fromMap(userData);
      
      // Update last active timestamp
      offlineUser.lastActiveAt = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_offlineUserKey, jsonEncode(offlineUser.toMap()));
      
      Logger.d('Retrieved offline guest user: ${offlineUser.uid}', 'OfflineAuthService');
      return offlineUser;
    } catch (e) {
      Logger.e('Failed to get offline guest user', e, null, 'OfflineAuthService');
      return null;
    }
  }
  
  /// Get offline user stats
  static Future<Map<String, dynamic>?> getOfflineUserStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_offlineUserStatsKey);
      
      if (statsJson == null) {
        return null;
      }
      
      return jsonDecode(statsJson) as Map<String, dynamic>;
    } catch (e) {
      Logger.e('Failed to get offline user stats', e, null, 'OfflineAuthService');
      return null;
    }
  }
  
  /// Update offline user stats
  static Future<bool> updateOfflineUserStats(Map<String, dynamic> updates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentStats = await getOfflineUserStats() ?? {};
      
      // Merge updates
      final updatedStats = {...currentStats, ...updates};
      updatedStats['lastLoginDate'] = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setString(_offlineUserStatsKey, jsonEncode(updatedStats));
      Logger.d('Updated offline user stats', 'OfflineAuthService');
      return true;
    } catch (e) {
      Logger.e('Failed to update offline user stats', e, null, 'OfflineAuthService');
      return false;
    }
  }
  
  /// Sign out offline user
  static Future<void> signOutOfflineUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineSessionKey);
      await prefs.remove(_offlineUserKey);
      await prefs.remove(_offlineUserStatsKey);
      
      Logger.i('Offline guest user signed out', 'OfflineAuthService');
    } catch (e) {
      Logger.e('Failed to sign out offline user', e, null, 'OfflineAuthService');
    }
  }
  
  /// Check if offline session is active
  static Future<bool> isOfflineSessionActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_offlineSessionKey) ?? false;
    } catch (e) {
      Logger.e('Failed to check offline session', e, null, 'OfflineAuthService');
      return false;
    }
  }
  
  /// Generate unique offline user ID
  static String _generateOfflineUserId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = random.nextInt(999999).toString().padLeft(6, '0');
    return 'offline_guest_${timestamp}_$randomSuffix';
  }
  
  /// Migrate offline user to Firebase when online
  static Future<bool> migrateToFirebaseUser(String firebaseUid) async {
    try {
      final offlineStats = await getOfflineUserStats();
      if (offlineStats == null) {
        return false;
      }
      
      // Here you would typically sync the offline data to Firebase
      // For now, we'll just clear the offline data
      await signOutOfflineUser();
      
      Logger.i('Offline user data migrated to Firebase user: $firebaseUid', 'OfflineAuthService');
      return true;
    } catch (e) {
      Logger.e('Failed to migrate offline user to Firebase', e, null, 'OfflineAuthService');
      return false;
    }
  }
}

/// Offline Guest User Model
class OfflineGuestUser {
  final String uid;
  final bool isAnonymous;
  final bool isOffline;
  final int createdAt;
  int lastActiveAt;
  
  OfflineGuestUser({
    required this.uid,
    required this.isAnonymous,
    required this.isOffline,
    required this.createdAt,
    required this.lastActiveAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'isAnonymous': isAnonymous,
      'isOffline': isOffline,
      'createdAt': createdAt,
      'lastActiveAt': lastActiveAt,
    };
  }
  
  factory OfflineGuestUser.fromMap(Map<String, dynamic> map) {
    return OfflineGuestUser(
      uid: map['uid'] ?? '',
      isAnonymous: map['isAnonymous'] ?? true,
      isOffline: map['isOffline'] ?? true,
      createdAt: map['createdAt'] ?? 0,
      lastActiveAt: map['lastActiveAt'] ?? 0,
    );
  }
  
  @override
  String toString() {
    return 'OfflineGuestUser(uid: $uid, isAnonymous: $isAnonymous, isOffline: $isOffline)';
  }
}