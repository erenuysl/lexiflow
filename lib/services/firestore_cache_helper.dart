// lib/services/firestore_cache_helper.dart
// Firestore Cache Helper for optimizing read operations

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

/// Cache entry with expiration time
class CacheEntry<T> {
  final T data;
  final DateTime expiryTime;
  
  CacheEntry(this.data, this.expiryTime);
  
  bool get isValid => DateTime.now().isBefore(expiryTime);
}

/// Firestore Cache Helper
/// Provides caching mechanism for Firestore read operations
class FirestoreCacheHelper {
  // Cache storage
  static final Map<String, CacheEntry<dynamic>> _documentCache = {};
  static final Map<String, CacheEntry<List<dynamic>>> _collectionCache = {};
  
  // LRU tracking
  static final List<String> _documentLRU = [];
  static final List<String> _collectionLRU = [];
  
  // Cache configuration
  static const int _maxDocumentCacheSize = 200;
  static const int _maxCollectionCacheSize = 50;
  static const Duration _defaultCacheDuration = Duration(minutes: 15);
  
  // Stream controllers for real-time updates
  static final Map<String, StreamController<dynamic>> _documentStreamControllers = {};
  static final Map<String, StreamController<List<dynamic>>> _collectionStreamControllers = {};
  
  /// Get document with caching
  static Future<T?> getDocument<T>({
    required DocumentReference<Map<String, dynamic>> reference,
    required T Function(Map<String, dynamic>? data, String id) mapper,
    Duration cacheDuration = _defaultCacheDuration,
    bool forceRefresh = false,
  }) async {
    final cacheKey = reference.path;
    
    // Check cache if not forcing refresh
    if (!forceRefresh && _documentCache.containsKey(cacheKey)) {
      final cacheEntry = _documentCache[cacheKey]!;
      if (cacheEntry.isValid) {
        // Update LRU
        _documentLRU.remove(cacheKey);
        _documentLRU.add(cacheKey);
        Logger.d('Cache hit for document: $cacheKey', 'FirestoreCacheHelper');
        return cacheEntry.data as T;
      }
    }
    
    try {
      final perfTask = Logger.startPerformanceTask('GetDocument', 'FirestoreCacheHelper');
      final docSnapshot = await reference.get();
      perfTask.finish();
      
      final result = mapper(docSnapshot.data(), docSnapshot.id);
      
      // Update cache
      _addToDocumentCache(cacheKey, result, cacheDuration);
      
      return result;
    } catch (e) {
      Logger.e('Error getting document', e, null, 'FirestoreCacheHelper');
      return null;
    }
  }
  
  /// Get collection with caching
  static Future<List<T>> getCollection<T>({
    required Query<Map<String, dynamic>> query,
    required T Function(Map<String, dynamic> data, String id) mapper,
    Duration cacheDuration = _defaultCacheDuration,
    bool forceRefresh = false,
  }) async {
    final cacheKey = query.toString();
    
    // Check cache if not forcing refresh
    if (!forceRefresh && _collectionCache.containsKey(cacheKey)) {
      final cacheEntry = _collectionCache[cacheKey]!;
      if (cacheEntry.isValid) {
        // Update LRU
        _collectionLRU.remove(cacheKey);
        _collectionLRU.add(cacheKey);
        Logger.d('Cache hit for collection: $cacheKey', 'FirestoreCacheHelper');
        return cacheEntry.data.cast<T>();
      }
    }
    
    try {
      final perfTask = Logger.startPerformanceTask('GetCollection', 'FirestoreCacheHelper');
      final querySnapshot = await query.get();
      perfTask.finish();
      
      final results = querySnapshot.docs.map((doc) => 
        mapper(doc.data(), doc.id)
      ).toList();
      
      // Update cache
      _addToCollectionCache(cacheKey, results, cacheDuration);
      
      return results;
    } catch (e) {
      Logger.e('Error getting collection', e, null, 'FirestoreCacheHelper');
      return [];
    }
  }
  
  /// Get real-time document stream with caching
  static Stream<T?> getDocumentStream<T>({
    required DocumentReference<Map<String, dynamic>> reference,
    required T Function(Map<String, dynamic>? data, String id) mapper,
    Duration cacheDuration = _defaultCacheDuration,
  }) {
    final cacheKey = reference.path;
    
    // Create or reuse stream controller
    if (!_documentStreamControllers.containsKey(cacheKey)) {
      _documentStreamControllers[cacheKey] = StreamController<T?>.broadcast();
      
      // Check cache first
      if (_documentCache.containsKey(cacheKey)) {
        final cacheEntry = _documentCache[cacheKey]!;
        if (cacheEntry.isValid) {
          _documentStreamControllers[cacheKey]!.add(cacheEntry.data as T);
        }
      }
      
      // Listen to Firestore updates
      reference.snapshots().listen((snapshot) {
        final result = mapper(snapshot.data(), snapshot.id);
        _addToDocumentCache(cacheKey, result, cacheDuration);
        _documentStreamControllers[cacheKey]!.add(result);
      }, onError: (e) {
        Logger.e('Error in document stream', e, null, 'FirestoreCacheHelper');
        _documentStreamControllers[cacheKey]!.addError(e);
      });
    }
    
    return _documentStreamControllers[cacheKey]!.stream as Stream<T?>;
  }
  
  /// Get real-time collection stream with caching
  static Stream<List<T>> getCollectionStream<T>({
    required Query<Map<String, dynamic>> query,
    required T Function(Map<String, dynamic> data, String id) mapper,
    Duration cacheDuration = _defaultCacheDuration,
  }) {
    final cacheKey = query.toString();
    
    // Create or reuse stream controller
    if (!_collectionStreamControllers.containsKey(cacheKey)) {
      _collectionStreamControllers[cacheKey] = StreamController<List<T>>.broadcast();
      
      // Check cache first
      if (_collectionCache.containsKey(cacheKey)) {
        final cacheEntry = _collectionCache[cacheKey]!;
        if (cacheEntry.isValid) {
          _collectionStreamControllers[cacheKey]!.add(cacheEntry.data.cast<T>());
        }
      }
      
      // Listen to Firestore updates
      query.snapshots().listen((snapshot) {
        final results = snapshot.docs.map((doc) => 
          mapper(doc.data(), doc.id)
        ).toList();
        
        _addToCollectionCache(cacheKey, results, cacheDuration);
        _collectionStreamControllers[cacheKey]!.add(results);
      }, onError: (e) {
        Logger.e('Error in collection stream', e, null, 'FirestoreCacheHelper');
        _collectionStreamControllers[cacheKey]!.addError(e);
      });
    }
    
    return _collectionStreamControllers[cacheKey]!.stream as Stream<List<T>>;
  }
  
  /// Add to document cache with LRU management
  static void _addToDocumentCache<T>(String key, T data, Duration cacheDuration) {
    // Manage cache size
    if (_documentCache.length >= _maxDocumentCacheSize && !_documentCache.containsKey(key)) {
      final oldestKey = _documentLRU.removeAt(0);
      _documentCache.remove(oldestKey);
      Logger.d('Removed oldest document from cache: $oldestKey', 'FirestoreCacheHelper');
    }
    
    // Update LRU
    _documentLRU.remove(key);
    _documentLRU.add(key);
    
    // Add to cache
    _documentCache[key] = CacheEntry<T>(
      data, 
      DateTime.now().add(cacheDuration)
    );
  }
  
  /// Add to collection cache with LRU management
  static void _addToCollectionCache<T>(String key, List<T> data, Duration cacheDuration) {
    // Manage cache size
    if (_collectionCache.length >= _maxCollectionCacheSize && !_collectionCache.containsKey(key)) {
      final oldestKey = _collectionLRU.removeAt(0);
      _collectionCache.remove(oldestKey);
      Logger.d('Removed oldest collection from cache: $oldestKey', 'FirestoreCacheHelper');
    }
    
    // Update LRU
    _collectionLRU.remove(key);
    _collectionLRU.add(key);
    
    // Add to cache
    _collectionCache[key] = CacheEntry<List<dynamic>>(
      data, 
      DateTime.now().add(cacheDuration)
    );
  }
  
  /// Invalidate document cache
  static void invalidateDocument(DocumentReference reference) {
    final cacheKey = reference.path;
    _documentCache.remove(cacheKey);
    _documentLRU.remove(cacheKey);
    Logger.d('Invalidated document cache: $cacheKey', 'FirestoreCacheHelper');
  }
  
  /// Invalidate collection cache
  static void invalidateCollection(Query query) {
    final cacheKey = query.toString();
    _collectionCache.remove(cacheKey);
    _collectionLRU.remove(cacheKey);
    Logger.d('Invalidated collection cache: $cacheKey', 'FirestoreCacheHelper');
  }
  
  /// Clear all caches
  static void clearAllCaches() {
    _documentCache.clear();
    _documentLRU.clear();
    _collectionCache.clear();
    _collectionLRU.clear();
    Logger.i('All Firestore caches cleared', 'FirestoreCacheHelper');
  }
  
  /// Dispose all resources
  static void dispose() {
    // Close all stream controllers
    for (final controller in _documentStreamControllers.values) {
      controller.close();
    }
    for (final controller in _collectionStreamControllers.values) {
      controller.close();
    }
    
    _documentStreamControllers.clear();
    _collectionStreamControllers.clear();
    
    // Clear caches
    clearAllCaches();
    
    Logger.i('FirestoreCacheHelper disposed', 'FirestoreCacheHelper');
  }
}