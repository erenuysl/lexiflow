// lib/services/offline_storage_manager.dart
// Offline storage manager for local data persistence

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Offline Storage Manager
/// Provides local storage capabilities for offline-first approach
class OfflineStorageManager {
  static final OfflineStorageManager _instance = OfflineStorageManager._internal();
  factory OfflineStorageManager() => _instance;
  
  SharedPreferences? _prefs;
  final Completer<void> _initCompleter = Completer<void>();
  
  // Storage keys
  static const String _pendingOperationsKey = 'pending_operations';
  static const String _userDataKey = 'user_data';
  static const String _userStatsKey = 'user_stats';
  static const String _wordCacheKey = 'word_cache';
  static const String _leaderboardCacheKey = 'leaderboard_cache';
  
  // Cache expiry (milliseconds)
  static const int _userDataExpiry = 24 * 60 * 60 * 1000; // 24 hours
  static const int _wordCacheExpiry = 12 * 60 * 60 * 1000; // 12 hours
  static const int _leaderboardCacheExpiry = 5 * 60 * 1000; // 5 minutes
  
  OfflineStorageManager._internal() {
    _init();
  }
  
  /// Initialize shared preferences
  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _initCompleter.complete();
      Logger.i('OfflineStorageManager initialized', 'OfflineStorageManager');
    } catch (e) {
      Logger.e('Error initializing OfflineStorageManager', e, null, 'OfflineStorageManager');
      _initCompleter.completeError(e);
    }
  }
  
  /// Ensure initialization is complete
  Future<void> ensureInitialized() async {
    return _initCompleter.future;
  }
  
  /// Save pending operations
  Future<bool> savePendingOperations(List<Map<String, dynamic>> operations) async {
    await ensureInitialized();
    try {
      final jsonString = jsonEncode(operations);
      final result = await _prefs!.setString(_pendingOperationsKey, jsonString);
      Logger.d('Saved ${operations.length} pending operations', 'OfflineStorageManager');
      return result;
    } catch (e) {
      Logger.e('Error saving pending operations', e, null, 'OfflineStorageManager');
      return false;
    }
  }
  
  /// Load pending operations
  Future<List<Map<String, dynamic>>> loadPendingOperations() async {
    await ensureInitialized();
    try {
      final jsonString = _prefs!.getString(_pendingOperationsKey);
      if (jsonString == null) {
        return [];
      }
      
      final List<dynamic> decoded = jsonDecode(jsonString);
      final operations = decoded.cast<Map<String, dynamic>>();
      Logger.d('Loaded ${operations.length} pending operations', 'OfflineStorageManager');
      return operations;
    } catch (e) {
      Logger.e('Error loading pending operations', e, null, 'OfflineStorageManager');
      return [];
    }
  }
  
  /// Save user data to local cache
  Future<bool> saveUserData(String userId, Map<String, dynamic> data) async {
    await ensureInitialized();
    try {
      // Clean data to remove Firestore-specific objects that can't be JSON encoded
      final cleanedData = _cleanFirestoreData(data);
      
      final cacheData = {
        'data': cleanedData,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final jsonString = jsonEncode(cacheData);
      final result = await _prefs!.setString('$_userDataKey:$userId', jsonString);
      Logger.d('Saved user data for $userId', 'OfflineStorageManager');
      return result;
    } catch (e) {
      Logger.e('Error saving user data', e, null, 'OfflineStorageManager');
      return false;
    }
  }
  
  /// Clean Firestore data to remove non-serializable objects
  Map<String, dynamic> _cleanFirestoreData(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};
    
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Handle different Firestore types
      if (value == null) {
        cleaned[key] = null;
      } else if (value is String || value is num || value is bool) {
        cleaned[key] = value;
      } else if (value is List) {
        cleaned[key] = value.map((item) => _cleanFirestoreValue(item)).toList();
      } else if (value is Map<String, dynamic>) {
        cleaned[key] = _cleanFirestoreData(value);
      } else {
        // Handle Firestore-specific types
        cleaned[key] = _cleanFirestoreValue(value);
      }
    }
    
    return cleaned;
  }
  
  /// Clean individual Firestore values
  dynamic _cleanFirestoreValue(dynamic value) {
    if (value == null) return null;
    
    // Handle Firestore Timestamp
    if (value.runtimeType.toString() == 'Timestamp') {
      try {
        // Convert Timestamp to milliseconds since epoch
        final timestamp = value as dynamic;
        return timestamp.millisecondsSinceEpoch;
      } catch (e) {
        return DateTime.now().millisecondsSinceEpoch;
      }
    }
    
    // Handle Firestore FieldValue (these should be resolved before saving)
    if (value.runtimeType.toString().contains('FieldValue')) {
      // FieldValue objects should not be saved to local storage
      // Return null or a default value
      return null;
    }
    
    // Handle other complex types
    if (value is String || value is num || value is bool) {
      return value;
    }
    
    // For unknown types, try to convert to string
    try {
      return value.toString();
    } catch (e) {
      return null;
    }
  }
  
  /// Load user data from local cache
  Future<Map<String, dynamic>?> loadUserData(String userId) async {
    await ensureInitialized();
    try {
      final jsonString = _prefs!.getString('$_userDataKey:$userId');
      if (jsonString == null) {
        return null;
      }
      
      final Map<String, dynamic> cacheData = jsonDecode(jsonString);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is expired
      if (now - timestamp > _userDataExpiry) {
        Logger.d('User data cache expired for $userId', 'OfflineStorageManager');
        return null;
      }
      
      Logger.d('Loaded user data for $userId from cache', 'OfflineStorageManager');
      return cacheData['data'] as Map<String, dynamic>;
    } catch (e) {
      Logger.e('Error loading user data', e, null, 'OfflineStorageManager');
      return null;
    }
  }
  
  /// Save word cache
  Future<bool> saveWordCache(String key, Map<String, dynamic> data) async {
    await ensureInitialized();
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final jsonString = jsonEncode(cacheData);
      final result = await _prefs!.setString('$_wordCacheKey:$key', jsonString);
      return result;
    } catch (e) {
      Logger.e('Error saving word cache', e, null, 'OfflineStorageManager');
      return false;
    }
  }
  
  /// Remove word cache
  Future<bool> removeWordCache(String key) async {
    await ensureInitialized();
    try {
      final result = await _prefs!.remove('$_wordCacheKey:$key');
      return result;
    } catch (e) {
      Logger.e('Error removing word cache', e, null, 'OfflineStorageManager');
      return false;
    }
  }
  
  /// Load word cache
  Future<Map<String, dynamic>?> loadWordCache(String key) async {
    await ensureInitialized();
    try {
      final jsonString = _prefs!.getString('$_wordCacheKey:$key');
      if (jsonString == null) {
        return null;
      }
      
      final Map<String, dynamic> cacheData = jsonDecode(jsonString);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is expired
      if (now - timestamp > _wordCacheExpiry) {
        return null;
      }
      
      return cacheData['data'] as Map<String, dynamic>;
    } catch (e) {
      Logger.e('Error loading word cache', e, null, 'OfflineStorageManager');
      return null;
    }
  }
  
  /// Save leaderboard cache
  Future<bool> saveLeaderboardCache(String key, List<Map<String, dynamic>> data) async {
    await ensureInitialized();
    try {
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final jsonString = jsonEncode(cacheData);
      final result = await _prefs!.setString('$_leaderboardCacheKey:$key', jsonString);
      return result;
    } catch (e) {
      Logger.e('Error saving leaderboard cache', e, null, 'OfflineStorageManager');
      return false;
    }
  }
  
  /// Load leaderboard cache
  Future<List<Map<String, dynamic>>?> loadLeaderboardCache(String key) async {
    await ensureInitialized();
    try {
      final jsonString = _prefs!.getString('$_leaderboardCacheKey:$key');
      if (jsonString == null) {
        return null;
      }
      
      final Map<String, dynamic> cacheData = jsonDecode(jsonString);
      final timestamp = cacheData['timestamp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is expired
      if (now - timestamp > _leaderboardCacheExpiry) {
        return null;
      }
      
      final List<dynamic> decoded = cacheData['data'] as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      Logger.e('Error loading leaderboard cache', e, null, 'OfflineStorageManager');
      return null;
    }
  }
  
  /// Clear all caches
  Future<bool> clearAllCaches() async {
    await ensureInitialized();
    try {
      final keys = _prefs!.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_userDataKey) || 
            key.startsWith(_wordCacheKey) || 
            key.startsWith(_leaderboardCacheKey)) {
          await _prefs!.remove(key);
        }
      }
      
      Logger.i('All caches cleared', 'OfflineStorageManager');
      return true;
    } catch (e) {
      Logger.e('Error clearing caches', e, null, 'OfflineStorageManager');
      return false;
    }
  }
  
  /// Clear expired caches
  Future<int> clearExpiredCaches() async {
    await ensureInitialized();
    int clearedCount = 0;
    
    try {
      final keys = _prefs!.getKeys();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final key in keys) {
        try {
          if (key.startsWith(_userDataKey) || 
              key.startsWith(_wordCacheKey) || 
              key.startsWith(_leaderboardCacheKey)) {
            
            final jsonString = _prefs!.getString(key);
            if (jsonString != null) {
              final Map<String, dynamic> cacheData = jsonDecode(jsonString);
              final timestamp = cacheData['timestamp'] as int;
              
              int expiryTime;
              if (key.startsWith(_userDataKey)) {
                expiryTime = _userDataExpiry;
              } else if (key.startsWith(_wordCacheKey)) {
                expiryTime = _wordCacheExpiry;
              } else {
                expiryTime = _leaderboardCacheExpiry;
              }
              
              if (now - timestamp > expiryTime) {
                await _prefs!.remove(key);
                clearedCount++;
              }
            }
          }
        } catch (e) {
          // Skip problematic entries
          Logger.w('Error processing cache entry: $key', 'OfflineStorageManager');
        }
      }
      
      Logger.i('Cleared $clearedCount expired cache entries', 'OfflineStorageManager');
      return clearedCount;
    } catch (e) {
      Logger.e('Error clearing expired caches', e, null, 'OfflineStorageManager');
      return clearedCount;
    }
  }
}