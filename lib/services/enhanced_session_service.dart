// lib/services/enhanced_session_service.dart
// Enhanced session service with real-time sync and optimization

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';
import 'session_service.dart';
import 'sync_manager.dart';
import 'offline_storage_manager.dart';

/// Enhanced session service with real-time synchronization and optimization
class EnhancedSessionService extends ChangeNotifier {
  static final EnhancedSessionService _instance = EnhancedSessionService._internal();
  factory EnhancedSessionService() => _instance;
  EnhancedSessionService._internal();

  final SessionService _sessionService = SessionService();
  final SyncManager _syncManager = SyncManager();
  final OfflineStorageManager _offlineStorage = OfflineStorageManager();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Real-time sync configuration
  static const int _syncIntervalMs = 5000; // 5 seconds as requested
  static const int _dbTimeoutMs = 10000; // 10 seconds timeout
  static const int _maxRequestSizeKb = 64; // 64KB max request size
  
  Timer? _syncTimer;
  StreamSubscription? _userDataSubscription;
  StreamSubscription? _leaderboardSubscription;
  
  bool _isRealTimeSyncEnabled = false;
  bool _isUpdating = false;
  
  // Getters
  bool get isUpdating => _isUpdating;
  bool get isRealTimeSyncEnabled => _isRealTimeSyncEnabled;
  
  /// Initialize enhanced session service
  Future<void> initialize() async {
    try {
      await _sessionService.initialize();
      await _syncManager.loadPendingOperations();
      await _offlineStorage.ensureInitialized();
      
      // Start real-time sync if user is authenticated
      if (_sessionService.isAuthenticated) {
        await enableRealTimeSync();
      }
      
      Logger.i('EnhancedSessionService initialized', 'EnhancedSessionService');
    } catch (e) {
      Logger.e('Failed to initialize EnhancedSessionService', e, null, 'EnhancedSessionService');
    }
  }

  /// Enable real-time synchronization
  Future<void> enableRealTimeSync() async {
    if (_isRealTimeSyncEnabled || !_sessionService.isAuthenticated) return;
    
    try {
      _isRealTimeSyncEnabled = true;
      
      // Start periodic sync timer
      _syncTimer = Timer.periodic(
        Duration(milliseconds: _syncIntervalMs),
        (_) => _performPeriodicSync(),
      );
      
      // Listen to user data changes
      _listenToUserDataChanges();
      
      // Listen to leaderboard changes
      _listenToLeaderboardChanges();
      
      Logger.i('Real-time sync enabled', 'EnhancedSessionService');
      notifyListeners();
    } catch (e) {
      Logger.e('Failed to enable real-time sync', e, null, 'EnhancedSessionService');
    }
  }

  /// Disable real-time synchronization
  void disableRealTimeSync() {
    _isRealTimeSyncEnabled = false;
    _syncTimer?.cancel();
    _userDataSubscription?.cancel();
    _leaderboardSubscription?.cancel();
    
    Logger.i('Real-time sync disabled', 'EnhancedSessionService');
    notifyListeners();
  }

  /// Listen to user data changes in real-time
  void _listenToUserDataChanges() {
    if (!_sessionService.isAuthenticated) return;
    
    final userId = _sessionService.currentUser!.uid;
    _userDataSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              _handleUserDataUpdate(snapshot.data()!);
            }
          },
          onError: (error) {
            Logger.e('Error listening to user data changes', error, null, 'EnhancedSessionService');
          },
        );
  }

  /// Listen to leaderboard changes in real-time
  void _listenToLeaderboardChanges() {
    if (!_sessionService.isAuthenticated) return;
    
    final userId = _sessionService.currentUser!.uid;
    _leaderboardSubscription = _firestore
        .collection('leaderboard_stats')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              _handleLeaderboardUpdate(snapshot.data()!);
            }
          },
          onError: (error) {
            Logger.e('Error listening to leaderboard changes', error, null, 'EnhancedSessionService');
          },
        );
  }

  /// Handle user data updates
  void _handleUserDataUpdate(Map<String, dynamic> data) {
    try {
      // Cache the updated data
      if (_sessionService.isAuthenticated) {
        _offlineStorage.saveUserData(_sessionService.currentUser!.uid, data);
      }
      
      // Notify listeners about the update
      notifyListeners();
      
      Logger.d('User data updated in real-time', 'EnhancedSessionService');
    } catch (e) {
      Logger.e('Error handling user data update', e, null, 'EnhancedSessionService');
    }
  }

  /// Handle leaderboard updates
  void _handleLeaderboardUpdate(Map<String, dynamic> data) {
    try {
      // Cache the updated leaderboard data
      _offlineStorage.saveLeaderboardCache('user_stats', [data]);
      
      // Notify listeners about the update
      notifyListeners();
      
      Logger.d('Leaderboard data updated in real-time', 'EnhancedSessionService');
    } catch (e) {
      Logger.e('Error handling leaderboard update', e, null, 'EnhancedSessionService');
    }
  }

  /// Perform periodic synchronization
  Future<void> _performPeriodicSync() async {
    if (!_sessionService.isAuthenticated || _isUpdating) return;
    
    try {
      // Check for pending operations and sync them
      if (_syncManager.pendingOperationsCount > 0 && _syncManager.isOnline) {
        Logger.d('Performing periodic sync with ${_syncManager.pendingOperationsCount} pending operations', 'EnhancedSessionService');
      }
    } catch (e) {
      Logger.e('Error during periodic sync', e, null, 'EnhancedSessionService');
    }
  }

  /// Enhanced display name update with real-time sync
  Future<Map<String, dynamic>> updateDisplayNameEnhanced(String displayName) async {
    if (!_sessionService.isAuthenticated) {
      return {'success': false, 'error': 'Kullanıcı oturumu bulunamadı'};
    }

    // Validate request size
    final requestSize = displayName.length * 2; // Approximate UTF-8 size
    if (requestSize > _maxRequestSizeKb * 1024) {
      return {'success': false, 'error': 'İsim çok uzun'};
    }

    _isUpdating = true;
    notifyListeners();

    try {
      // Use timeout for database operations
      final result = await _sessionService.updateDisplayName(displayName).timeout(
        Duration(milliseconds: _dbTimeoutMs),
      );

      if (result['success'] == true) {
        // Force immediate sync for critical updates
        await _forceSyncUserData(displayName);
        
        Logger.i('Display name updated successfully with enhanced sync', 'EnhancedSessionService');
      }

      return result;
    } on TimeoutException {
      return {'success': false, 'error': 'İstek zaman aşımına uğradı'};
    } catch (e) {
      Logger.e('Enhanced display name update failed', e, null, 'EnhancedSessionService');
      return {'success': false, 'error': 'İsim güncellenirken bir hata oluştu'};
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  /// Force immediate sync for critical user data updates
  Future<void> _forceSyncUserData(String displayName) async {
    if (!_sessionService.isAuthenticated) return;

    try {
      final userId = _sessionService.currentUser!.uid;
      
      // Update both user_data and leaderboard_stats collections immediately
      final batch = _firestore.batch();
      
      // Update user_data
      final userDataRef = _firestore
          .collection('users')
          .doc(userId);
      
      batch.update(userDataRef, {
        'displayName': displayName,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Update leaderboard_stats
      final leaderboardRef = _firestore
          .collection('leaderboard_stats')
          .doc(userId);
      
      batch.update(leaderboardRef, {
        'displayName': displayName,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      // Commit with timeout
      await batch.commit().timeout(
        Duration(milliseconds: _dbTimeoutMs),
      );
      
      // Clear relevant caches
      await _clearRelevantCaches();
      
      Logger.i('Forced sync completed for display name update', 'EnhancedSessionService');
    } catch (e) {
      Logger.e('Error during forced sync', e, null, 'EnhancedSessionService');
      // Add to sync queue for retry
      await _syncManager.addOperation(
        path: 'users/${_sessionService.currentUser!.uid}',
        type: SyncOperationType.update,
        data: {'displayName': displayName},
      );
    }
  }

  /// Clear relevant caches after updates
  Future<void> _clearRelevantCaches() async {
    try {
      // Clear user data cache
      if (_sessionService.isAuthenticated) {
        final userId = _sessionService.currentUser!.uid;
        await _offlineStorage.saveUserData(userId, {});
      }
      
      // Clear leaderboard cache
      await _offlineStorage.saveLeaderboardCache('user_stats', []);
      
      Logger.d('Relevant caches cleared', 'EnhancedSessionService');
    } catch (e) {
      Logger.e('Error clearing caches', e, null, 'EnhancedSessionService');
    }
  }

  /// Get sync status for UI components
  Stream<SyncStatus> get syncStatusStream => _syncManager.syncStatusStream;
  
  /// Get online status
  bool get isOnline => _syncManager.isOnline;
  
  /// Get pending operations count
  int get pendingOperationsCount => _syncManager.pendingOperationsCount;

  /// Dispose resources
  @override
  void dispose() {
    disableRealTimeSync();
    super.dispose();
  }
}