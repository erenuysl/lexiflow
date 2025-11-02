// lib/services/cloud_sync_service.dart
// Comprehensive cloud sync service for offline-first user data management

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_data.dart';
import '../models/achievement.dart';
import '../utils/logger.dart';
import 'connectivity_service.dart';

part 'cloud_sync_service.g.dart';

/// Sync status for UI indicators
enum CloudSyncStatus {
  online,     // 🟢 online & synced
  syncing,    // 🟡 syncing
  offline,    // 🔴 offline
  synced,     // ✅ synced
  error,      // ❌ error
}

/// Cached user data structure for Hive storage
@HiveType(typeId: 10)
class CachedUserData extends HiveObject {
  @HiveField(0)
  int learnedWordsCount;

  @HiveField(1)
  int currentStreak;

  @HiveField(2)
  int totalQuizzesCompleted;

  @HiveField(3)
  int totalXp;

  @HiveField(4)
  Map<String, dynamic> achievements;

  @HiveField(5)
  DateTime lastSyncTime;

  @HiveField(6)
  bool isDirty; // needs sync

  CachedUserData({
    required this.learnedWordsCount,
    required this.currentStreak,
    required this.totalQuizzesCompleted,
    required this.totalXp,
    required this.achievements,
    required this.lastSyncTime,
    this.isDirty = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'learnedWordsCount': learnedWordsCount,
      'currentStreak': currentStreak,
      'totalQuizzesCompleted': totalQuizzesCompleted,
      'totalXp': totalXp,
      'achievements': achievements,
      'lastSyncTime': lastSyncTime.toIso8601String(),
      'isDirty': isDirty,
    };
  }

  factory CachedUserData.fromMap(Map<String, dynamic> map) {
    return CachedUserData(
      learnedWordsCount: map['learnedWordsCount'] ?? 0,
      currentStreak: map['currentStreak'] ?? 0,
      totalQuizzesCompleted: map['totalQuizzesCompleted'] ?? 0,
      totalXp: map['totalXp'] ?? 0,
      achievements: Map<String, dynamic>.from(map['achievements'] ?? {}),
      lastSyncTime: DateTime.parse(map['lastSyncTime'] ?? DateTime.now().toIso8601String()),
      isDirty: map['isDirty'] ?? false,
    );
  }
}

/// Cloud Sync Service
/// Manages bi-directional sync between Firestore and Hive with conflict resolution
class CloudSyncService extends ChangeNotifier {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivity = ConnectivityService();
  
  // Hive boxes
  Box<CachedUserData>? _userDataBox;
  Box<String>? _syncQueueBox;
  
  // State management
  CloudSyncStatus _syncStatus = CloudSyncStatus.offline;
  bool _isInitialized = false;
  bool _isSyncing = false;
  String? _currentUserId;
  
  // Sync configuration
  static const Duration _syncInterval = Duration(seconds: 30);
  static const Duration _conflictResolutionTimeout = Duration(seconds: 10);
  
  Timer? _syncTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription? _firestoreSubscription;
  
  // Getters
  CloudSyncStatus get syncStatus => _syncStatus;
  bool get isOnline => _syncStatus != CloudSyncStatus.offline;
  bool get isSyncing => _isSyncing;
  bool get isInitialized => _isInitialized;
  
  CloudSyncService._internal();

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Logger.i('🔄 Initializing CloudSyncService...', 'CloudSyncService');
      
      // Initialize Hive boxes
      await _initializeHiveBoxes();
      
      // Setup connectivity monitoring
      await _setupConnectivityMonitoring();
      
      _isInitialized = true;
      Logger.i('✅ CloudSyncService initialized successfully', 'CloudSyncService');
    } catch (e) {
      Logger.e('Failed to initialize CloudSyncService', e, null, 'CloudSyncService');
      rethrow;
    }
  }

  /// Initialize Hive boxes for local storage
  Future<void> _initializeHiveBoxes() async {
    try {
      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(10)) {
        Hive.registerAdapter(CachedUserDataAdapter());
      }
      
      // Open boxes
      _userDataBox = await Hive.openBox<CachedUserData>('cached_user_data');
      _syncQueueBox = await Hive.openBox<String>('sync_queue');
      
      Logger.d('Hive boxes initialized successfully', 'CloudSyncService');
    } catch (e) {
      Logger.e('Failed to initialize Hive boxes', e, null, 'CloudSyncService');
      rethrow;
    }
  }

  /// Setup connectivity monitoring
  Future<void> _setupConnectivityMonitoring() async {
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onlineStatusStream.listen((bool isOnline) {
      _handleConnectivityChange(isOnline);
    });
    
    // Check initial connectivity
    final bool isOnline = _connectivity.isOnline;
    _handleConnectivityChange(isOnline);
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(bool isOnline) {
    final previousStatus = _syncStatus;
    
    if (isOnline) {
      _syncStatus = CloudSyncStatus.online;
      Logger.i('🌐 Device is online, starting sync', 'CloudSyncService');
      _startPeriodicSync();
    } else {
      _syncStatus = CloudSyncStatus.offline;
      Logger.i('📴 Device is offline', 'CloudSyncService');
      _stopPeriodicSync();
    }
    
    if (previousStatus != _syncStatus) {
      notifyListeners();
    }
  }

  /// Start periodic sync when online
  void _startPeriodicSync() {
    _stopPeriodicSync(); // Clear any existing timer
    
    if (_currentUserId != null) {
      // Immediate sync
      _performSync();
      
      // Setup periodic sync
      _syncTimer = Timer.periodic(_syncInterval, (_) {
        if (_syncStatus == CloudSyncStatus.online && !_isSyncing) {
          _performSync();
        }
      });
    }
  }

  /// Stop periodic sync
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Set current user and start monitoring
  Future<void> setUser(String userId) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    _currentUserId = userId;
    Logger.i('👤 User set: $userId', 'CloudSyncService');
    
    // Start Firestore listener for real-time updates
    await _setupFirestoreListener();
    
    // Start sync if online
    if (_syncStatus == CloudSyncStatus.online) {
      _startPeriodicSync();
    }
  }

  /// Setup Firestore listener for real-time updates
  Future<void> _setupFirestoreListener() async {
    if (_currentUserId == null) return;
    
    _firestoreSubscription?.cancel();
    
    try {
      _firestoreSubscription = _firestore
          .collection('users')
          .doc(_currentUserId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && !_isSyncing) {
          _handleFirestoreUpdate(snapshot.data()!);
        }
      });
      
      Logger.d('Firestore listener setup for user: $_currentUserId', 'CloudSyncService');
    } catch (e) {
      Logger.e('Failed to setup Firestore listener', e, null, 'CloudSyncService');
    }
  }

  /// Handle Firestore updates (conflict resolution)
  void _handleFirestoreUpdate(Map<String, dynamic> firestoreData) {
    if (_currentUserId == null) return;
    
    try {
      final localData = _userDataBox?.get(_currentUserId!);
      
      if (localData != null) {
        // Check if Firestore data is newer
        final firestoreTimestamp = firestoreData['lastUpdated'] as Timestamp?;
        final localTimestamp = localData.lastSyncTime;
        
        if (firestoreTimestamp != null && 
            firestoreTimestamp.toDate().isAfter(localTimestamp)) {
          
          Logger.i('🔄 Firestore data is newer, updating local cache', 'CloudSyncService');
          _updateLocalFromFirestore(firestoreData);
        }
      } else {
        // No local data, create from Firestore
        Logger.i('📥 Creating local cache from Firestore data', 'CloudSyncService');
        _updateLocalFromFirestore(firestoreData);
      }
    } catch (e) {
      Logger.e('Error handling Firestore update', e, null, 'CloudSyncService');
    }
  }

  /// Update local cache from Firestore data
  void _updateLocalFromFirestore(Map<String, dynamic> firestoreData) {
    if (_currentUserId == null) return;
    
    try {
      final cachedData = CachedUserData(
        learnedWordsCount: firestoreData['totalWordsLearned'] ?? 0,
        currentStreak: firestoreData['currentStreak'] ?? 0,
        totalQuizzesCompleted: firestoreData['totalQuizzesTaken'] ?? 0,
        totalXp: firestoreData['totalXp'] ?? 0,
        achievements: Map<String, dynamic>.from(firestoreData['achievements'] ?? {}),
        lastSyncTime: DateTime.now(),
        isDirty: false,
      );
      
      _userDataBox?.put(_currentUserId!, cachedData);
      Logger.d('Local cache updated from Firestore', 'CloudSyncService');
      
      notifyListeners();
    } catch (e) {
      Logger.e('Error updating local cache from Firestore', e, null, 'CloudSyncService');
    }
  }

  /// Get cached user data (offline-first)
  CachedUserData? getCachedUserData() {
    if (_currentUserId == null) return null;
    return _userDataBox?.get(_currentUserId!);
  }

  /// Update local cache and mark for sync
  Future<void> updateLocalData({
    int? learnedWordsCount,
    int? currentStreak,
    int? totalQuizzesCompleted,
    int? totalXp,
    Map<String, dynamic>? achievements,
  }) async {
    if (_currentUserId == null) return;
    
    try {
      final existing = _userDataBox?.get(_currentUserId!) ?? CachedUserData(
        learnedWordsCount: 0,
        currentStreak: 0,
        totalQuizzesCompleted: 0,
        totalXp: 0,
        achievements: {},
        lastSyncTime: DateTime.now(),
        isDirty: false,
      );
      
      final updated = CachedUserData(
        learnedWordsCount: learnedWordsCount ?? existing.learnedWordsCount,
        currentStreak: currentStreak ?? existing.currentStreak,
        totalQuizzesCompleted: totalQuizzesCompleted ?? existing.totalQuizzesCompleted,
        totalXp: totalXp ?? existing.totalXp,
        achievements: achievements ?? existing.achievements,
        lastSyncTime: DateTime.now(),
        isDirty: true, // Mark as needing sync
      );
      
      await _userDataBox?.put(_currentUserId!, updated);
      Logger.d('Local data updated and marked for sync', 'CloudSyncService');
      
      // Trigger immediate sync if online
      if (_syncStatus == CloudSyncStatus.online && !_isSyncing) {
        _performSync();
      }
      
      notifyListeners();
    } catch (e) {
      Logger.e('Error updating local data', e, null, 'CloudSyncService');
    }
  }

  /// Perform bi-directional sync
  Future<void> _performSync() async {
    if (_currentUserId == null || _isSyncing) return;
    
    _isSyncing = true;
    _syncStatus = CloudSyncStatus.syncing;
    notifyListeners();
    
    try {
      Logger.d('🔄 Starting sync for user: $_currentUserId', 'CloudSyncService');
      
      final localData = _userDataBox?.get(_currentUserId!);
      if (localData == null || !localData.isDirty) {
        Logger.d('No local changes to sync', 'CloudSyncService');
        return;
      }
      
      // Upload local changes to Firestore
      await _uploadToFirestore(localData);
      
      // Mark as synced
      localData.isDirty = false;
      localData.lastSyncTime = DateTime.now();
      await _userDataBox?.put(_currentUserId!, localData);
      
      Logger.i('✅ Sync completed successfully', 'CloudSyncService');
      
    } catch (e) {
      Logger.e('Sync failed', e, null, 'CloudSyncService');
    } finally {
      _isSyncing = false;
      _syncStatus = CloudSyncStatus.online;
      notifyListeners();
    }
  }

  /// Upload local data to Firestore
  Future<void> _uploadToFirestore(CachedUserData localData) async {
    if (_currentUserId == null) return;
    
    try {
      final updateData = {
        'totalWordsLearned': localData.learnedWordsCount,
        'currentStreak': localData.currentStreak,
        'totalQuizzesTaken': localData.totalQuizzesCompleted,
        'totalXp': localData.totalXp,
        'achievements': localData.achievements,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection('users')
          .doc(_currentUserId!)
          .update(updateData);
      
      Logger.d('Data uploaded to Firestore successfully', 'CloudSyncService');
    } catch (e) {
      Logger.e('Failed to upload data to Firestore', e, null, 'CloudSyncService');
      rethrow;
    }
  }

  /// Force sync (manual trigger)
  Future<void> forceSync() async {
    if (_syncStatus == CloudSyncStatus.offline) {
      Logger.w('Cannot sync while offline', 'CloudSyncService');
      return;
    }
    
    Logger.i('🔄 Manual sync triggered', 'CloudSyncService');
    await _performSync();
  }

  /// Clear user data and stop monitoring
  Future<void> clearUser() async {
    _currentUserId = null;
    _firestoreSubscription?.cancel();
    _stopPeriodicSync();
    
    Logger.i('👤 User cleared from sync service', 'CloudSyncService');
  }

  /// Get Turkish status text for UI
  String getStatusText() {
    switch (_syncStatus) {
      case CloudSyncStatus.online:
        return 'Güncel';
      case CloudSyncStatus.syncing:
        return 'Senkronize ediliyor';
      case CloudSyncStatus.offline:
        return 'Çevrimdışı';
      case CloudSyncStatus.synced:
        return 'Senkronize edildi';
      case CloudSyncStatus.error:
        return 'Hata';
    }
  }

  /// Get status icon for UI
  String getStatusIcon() {
    switch (_syncStatus) {
      case CloudSyncStatus.online:
        return '🟢';
      case CloudSyncStatus.syncing:
        return '🟡';
      case CloudSyncStatus.offline:
        return '🔴';
      case CloudSyncStatus.synced:
        return '✅';
      case CloudSyncStatus.error:
        return '❌';
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _firestoreSubscription?.cancel();
    _stopPeriodicSync();
    _userDataBox?.close();
    _syncQueueBox?.close();
    
    Logger.i('CloudSyncService disposed', 'CloudSyncService');
    super.dispose();
  }
}