// lib/providers/sync_status_provider.dart
// Provider for managing sync status across the app

import 'package:flutter/foundation.dart';
import '../services/cloud_sync_service.dart';

/// Sync Status Provider
/// Manages sync status state across the application
class SyncStatusProvider extends ChangeNotifier {
  final CloudSyncService _syncService = CloudSyncService();
  
  CloudSyncStatus get syncStatus => _syncService.syncStatus;
  bool get isOnline => _syncService.isOnline;
  bool get isSyncing => _syncService.isSyncing;
  bool get isInitialized => _syncService.isInitialized;
  
  SyncStatusProvider() {
    _syncService.addListener(_onSyncStatusChanged);
  }
  
  void _onSyncStatusChanged() {
    notifyListeners();
  }
  
  /// Initialize sync service
  Future<void> initialize() async {
    await _syncService.initialize();
  }
  
  /// Set current user
  Future<void> setUser(String userId) async {
    await _syncService.setUser(userId);
  }
  
  /// Force sync
  Future<void> forceSync() async {
    await _syncService.forceSync();
  }
  
  /// Clear user
  Future<void> clearUser() async {
    await _syncService.clearUser();
  }
  
  /// Get status text in Turkish
  String getStatusText() {
    return _syncService.getStatusText();
  }
  
  /// Get status icon
  String getStatusIcon() {
    return _syncService.getStatusIcon();
  }
  
  /// Update local data
  Future<void> updateLocalData({
    int? learnedWordsCount,
    int? currentStreak,
    int? totalQuizzesCompleted,
    int? totalXp,
    Map<String, dynamic>? achievements,
  }) async {
    await _syncService.updateLocalData(
      learnedWordsCount: learnedWordsCount,
      currentStreak: currentStreak,
      totalQuizzesCompleted: totalQuizzesCompleted,
      totalXp: totalXp,
      achievements: achievements,
    );
  }
  
  /// Get cached user data
  CachedUserData? getCachedUserData() {
    return _syncService.getCachedUserData();
  }
  
  @override
  void dispose() {
    _syncService.removeListener(_onSyncStatusChanged);
    super.dispose();
  }
}