// lib/services/sync_manager.dart
// Event-based synchronization manager for Firestore operations

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';

/// Sync operation status
enum SyncStatus {
  pending,
  inProgress,
  completed,
  failed,
}

/// Sync operation type
enum SyncOperationType {
  create,
  update,
  delete,
}

/// Sync operation model
class SyncOperation {
  final String id;
  final String path;
  final SyncOperationType type;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  SyncStatus status;
  int retryCount;
  
  SyncOperation({
    required this.id,
    required this.path,
    required this.type,
    this.data,
    required this.createdAt,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'type': type.toString().split('.').last,
      'data': data,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'status': status.toString().split('.').last,
      'retryCount': retryCount,
    };
  }
  
  factory SyncOperation.fromMap(Map<String, dynamic> map) {
    return SyncOperation(
      id: map['id'],
      path: map['path'],
      type: SyncOperationType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
      ),
      data: map['data'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      status: SyncStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
      ),
      retryCount: map['retryCount'],
    );
  }
}

/// Sync Manager for handling offline-first and event-based synchronization
class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<SyncOperation> _pendingOperations = [];
  final StreamController<List<SyncOperation>> _pendingOperationsController = StreamController<List<SyncOperation>>.broadcast();
  
  bool _isOnline = true;
  bool _isSyncing = false;
  Timer? _syncTimer;
  Timer? _debounceTimer;
  StreamSubscription? _connectivitySubscription;
  
  // Event streams
  Stream<List<SyncOperation>> get pendingOperations => _pendingOperationsController.stream;
  Stream<List<SyncOperation>> get pendingOperationsStream => _pendingOperationsController.stream;
  final StreamController<bool> _syncStatusController = StreamController<bool>.broadcast();
  Stream<bool> get syncStatus => _syncStatusController.stream;
  
  // SyncStatus stream for UI components
  final StreamController<SyncStatus> _syncStatusStreamController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatusStream => _syncStatusStreamController.stream;
  
  SyncManager._internal() {
    _initConnectivityListener();
  }
  
  /// Initialize connectivity listener
  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _handleConnectivityChangeWithDebounce(result);
    });
    
    // Check initial connectivity
    Connectivity().checkConnectivity().then((result) {
      _handleConnectivityChange(result);
    });
  }
  
  /// Handle connectivity changes with debounce to prevent flicker
  void _handleConnectivityChangeWithDebounce(ConnectivityResult result) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _handleConnectivityChange(result);
    });
  }
  
  /// Handle connectivity changes
  void _handleConnectivityChange(ConnectivityResult result) {
    final wasOnline = _isOnline;
    final isOnline = result != ConnectivityResult.none;
    
    // Always update the status, even if it seems the same
    _isOnline = isOnline;
    
    if (!wasOnline && _isOnline) {
      Logger.i('🌐 Device is back online, starting sync', 'SyncManager');
      _startSync();
    } else if (wasOnline && !_isOnline) {
      Logger.i('📴 Device is offline, pausing sync', 'SyncManager');
      _pauseSync();
    }
    
    // Always update streams to ensure UI reflects current status
    _updateStreams();
  }
  
  /// Update all streams with current status
  void _updateStreams() {
    // Update bool stream for ConnectionStatusWidget - this should reflect actual connectivity
    _syncStatusController.add(_isOnline);
    
    // Update SyncStatus stream for OfflineIndicator
    if (_isOnline) {
      if (_pendingOperations.isNotEmpty) {
        _syncStatusStreamController.add(SyncStatus.inProgress);
      } else {
        _syncStatusStreamController.add(SyncStatus.completed);
      }
    } else {
      _syncStatusStreamController.add(SyncStatus.pending);
    }
  }
  
  /// Add operation to sync queue
  Future<void> addOperation({
    required String path,
    required SyncOperationType type,
    Map<String, dynamic>? data,
  }) async {
    final operation = SyncOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      path: path,
      type: type,
      data: data,
      createdAt: DateTime.now(),
    );
    
    _pendingOperations.add(operation);
    _pendingOperationsController.add(_pendingOperations);
    
    Logger.d('Added operation to sync queue: ${operation.type} - ${operation.path}', 'SyncManager');
    
    // Try to sync immediately if online
    if (_isOnline && !_isSyncing) {
      _startSync();
    }
    
    // Save pending operations to local storage
    await _savePendingOperations();
  }

  /// Force a sync attempt - useful for manual retry
  void forceSyncAttempt() {
    Logger.i('🔄 Manual sync attempt triggered', 'SyncManager');
    
    // Check connectivity first
    Connectivity().checkConnectivity().then((result) {
      _handleConnectivityChange(result);
      
      // If we're online and have pending operations, start sync
      if (_isOnline && _pendingOperations.isNotEmpty && !_isSyncing) {
        _startSync();
      }
    });
  }
  
  /// Start sync process
  void _startSync() {
    if (_isSyncing || _pendingOperations.isEmpty || !_isOnline) {
      return;
    }
    
    _isSyncing = true;
    _syncStatusController.add(true);
    
    _processPendingOperations().then((_) {
      _isSyncing = false;
      _syncStatusController.add(false);
      
      // Schedule next sync if there are still pending operations
      if (_pendingOperations.isNotEmpty) {
        _scheduleNextSync();
      }
    });
  }
  
  /// Pause sync process
  void _pauseSync() {
    _syncTimer?.cancel();
    _isSyncing = false;
    _syncStatusController.add(false);
  }
  
  /// Schedule next sync attempt
  void _scheduleNextSync() {
    _syncTimer?.cancel();
    
    // Exponential backoff based on number of failed operations
    final maxRetryCount = _pendingOperations.fold<int>(
      0, 
      (max, op) => op.retryCount > max ? op.retryCount : max
    );
    
    final delay = _calculateBackoffDelay(maxRetryCount);
    
    _syncTimer = Timer(delay, () {
      if (_isOnline) {
        _startSync();
      }
    });
    
    Logger.d('Next sync scheduled in ${delay.inSeconds} seconds', 'SyncManager');
  }
  
  /// Calculate backoff delay based on retry count
  Duration _calculateBackoffDelay(int retryCount) {
    // Base delay is 5 seconds
    // Max delay is 5 minutes
    final seconds = 5 * (1 << retryCount.clamp(0, 6));
    return Duration(seconds: seconds.clamp(5, 300));
  }
  
  /// Process pending operations
  Future<void> _processPendingOperations() async {
    if (_pendingOperations.isEmpty) {
      return;
    }
    
    Logger.i('Processing ${_pendingOperations.length} pending operations', 'SyncManager');
    
    // Sort operations by creation time
    _pendingOperations.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    // Process operations in batches
    final batch = _firestore.batch();
    final processedOperations = <SyncOperation>[];
    int batchSize = 0;
    
    for (final operation in _pendingOperations) {
      if (batchSize >= 400) {
        // Commit current batch and start a new one
        await _commitBatch(batch, processedOperations);
        processedOperations.clear();
        batchSize = 0;
      }
      
      try {
        final docRef = _firestore.doc(operation.path);
        
        switch (operation.type) {
          case SyncOperationType.create:
          case SyncOperationType.update:
            if (operation.data != null) {
              batch.set(docRef, operation.data!, SetOptions(merge: true));
            }
            break;
          case SyncOperationType.delete:
            batch.delete(docRef);
            break;
        }
        
        operation.status = SyncStatus.inProgress;
        processedOperations.add(operation);
        batchSize++;
      } catch (e) {
        Logger.e('Error processing operation', e, null, 'SyncManager');
        operation.status = SyncStatus.failed;
        operation.retryCount++;
      }
    }
    
    // Commit any remaining operations
    if (processedOperations.isNotEmpty) {
      await _commitBatch(batch, processedOperations);
    }
    
    // Update pending operations list
    _pendingOperationsController.add(_pendingOperations);
    
    // Save updated pending operations to local storage
    await _savePendingOperations();
  }
  
  /// Commit batch and update operation statuses
  Future<void> _commitBatch(WriteBatch batch, List<SyncOperation> operations) async {
    try {
      await batch.commit();
      
      // Mark operations as completed
      for (final operation in operations) {
        operation.status = SyncStatus.completed;
      }
      
      // Remove completed operations from pending list
      _pendingOperations.removeWhere((op) => op.status == SyncStatus.completed);
      
      Logger.i('Successfully committed ${operations.length} operations', 'SyncManager');
    } catch (e) {
      Logger.e('Error committing batch', e, null, 'SyncManager');
      
      // Mark operations as failed
      for (final operation in operations) {
        operation.status = SyncStatus.failed;
        operation.retryCount++;
      }
    }
  }
  
  /// Save pending operations to local storage
  Future<void> _savePendingOperations() async {
    try {
      // Filter out completed operations
      final operations = _pendingOperations
          .where((op) => op.status != SyncStatus.completed)
          .map((op) => op.toMap())
          .toList();
      
      // Save to local storage (implementation depends on storage solution)
      // For now, just log the count
      Logger.d('Saved ${operations.length} pending operations', 'SyncManager');
    } catch (e) {
      Logger.e('Error saving pending operations', e, null, 'SyncManager');
    }
  }
  
  /// Load pending operations from local storage
  Future<void> loadPendingOperations() async {
    try {
      // Load from local storage (implementation depends on storage solution)
      // For now, just log
      Logger.d('Loaded pending operations', 'SyncManager');
    } catch (e) {
      Logger.e('Error loading pending operations', e, null, 'SyncManager');
    }
  }
  
  /// Get current sync status
  bool get isSyncing => _isSyncing;
  
  /// Get current online status
  bool get isOnline => _isOnline;
  
  /// Get pending operations count
  int get pendingOperationsCount => _pendingOperations.length;
  
  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _pendingOperationsController.close();
    _syncStatusController.close();
    Logger.i('SyncManager disposed', 'SyncManager');
  }
}