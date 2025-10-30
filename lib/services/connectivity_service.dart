import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Enhanced connectivity service that provides real-time network status
/// and direct connectivity checks to fix false offline detection issues
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Current connectivity state
  ConnectivityResult _currentResult = ConnectivityResult.none;
  bool _isOnline = false;
  bool _isInitialized = false; // Flag to prevent initial false notifications
  
  // Stream controllers for real-time updates
  final StreamController<bool> _onlineStatusController = StreamController<bool>.broadcast();
  final StreamController<ConnectivityResult> _connectivityController = StreamController<ConnectivityResult>.broadcast();
  
  // Public streams
  Stream<bool> get onlineStatusStream => _onlineStatusController.stream;
  Stream<ConnectivityResult> get connectivityStream => _connectivityController.stream;
  
  // Current status getters
  bool get isOnline => _isOnline;
  ConnectivityResult get currentResult => _currentResult;

  /// Initialize the connectivity service
  Future<void> initialize() async {
    // Get initial connectivity status
    try {
      _currentResult = await _connectivity.checkConnectivity();
      _isOnline = _currentResult != ConnectivityResult.none;
      
      // Emit initial status only after marking as initialized
      _isInitialized = true;
      _onlineStatusController.add(_isOnline);
      _connectivityController.add(_currentResult);
      
      if (kDebugMode) {
        print('🌐 ConnectivityService initialized - Online: $_isOnline, Result: $_currentResult');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to get initial connectivity: $e');
      }
      // Assume offline on error
      _isOnline = false;
      _currentResult = ConnectivityResult.none;
      _isInitialized = true;
      _onlineStatusController.add(false);
      _connectivityController.add(ConnectivityResult.none);
    }
    
    // Start listening to connectivity changes
    _startListening();
  }

  /// Start listening to connectivity changes
  void _startListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (error) {
        if (kDebugMode) {
          print('⚠️ Connectivity stream error: $error');
        }
        // On error, assume offline
        _handleConnectivityChange(ConnectivityResult.none);
      },
    );
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _currentResult = result;
    _isOnline = result != ConnectivityResult.none;
    
    // Only emit if status actually changed and service is initialized
    if (_isInitialized && wasOnline != _isOnline) {
      _onlineStatusController.add(_isOnline);
      
      if (kDebugMode) {
        print('🌐 Connectivity changed: ${wasOnline ? 'Online' : 'Offline'} → ${_isOnline ? 'Online' : 'Offline'} ($result)');
      }
    }
    
    // Always emit connectivity result changes if initialized
    if (_isInitialized) {
      _connectivityController.add(result);
    }
  }
  
  /// Check current connectivity status directly
  /// This is the method that should replace SyncManager().syncStatus checks
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final isOnline = result != ConnectivityResult.none;
      
      // Update internal state if different
      if (_currentResult != result || _isOnline != isOnline) {
        _handleConnectivityChange(result);
      }
      
      return isOnline;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to check connectivity: $e');
      }
      return false; // Assume offline on error
    }
  }
  
  /// Get connectivity result as string for debugging
  String get connectivityString {
    switch (_currentResult) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'None';
    }
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _onlineStatusController.close();
    _connectivityController.close();
  }
}