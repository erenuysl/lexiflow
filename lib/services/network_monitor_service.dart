import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'connectivity_service.dart';
import 'session_service.dart';

/// Sürekli ağ bağlantısını izleyen ve otomatik geçişleri yöneten servis
class NetworkMonitorService {
  static final NetworkMonitorService _instance = NetworkMonitorService._internal();
  factory NetworkMonitorService() => _instance;
  NetworkMonitorService._internal();

  StreamSubscription<bool>? _connectivitySubscription;
  bool _isMonitoring = false;
  bool _wasOfflineAsGuest = false;
  bool _isInitialConnection = true; // Flag to prevent initial connection notification
  bool _wasActuallyOffline = false; // Track if we were genuinely offline
  BuildContext? _context;

  /// Ağ izlemeyi başlat
  void startMonitoring(BuildContext context) {
    if (_isMonitoring) return;
    
    _context = context;
    _isMonitoring = true;
    
    _connectivitySubscription = ConnectivityService().onlineStatusStream.listen((isOnline) {
      _handleConnectivityChange(isOnline);
    });
  }

  /// Ağ izlemeyi durdur
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _isMonitoring = false;
    _context = null;
  }

  /// Bağlantı değişikliklerini yönet
  void _handleConnectivityChange(bool isOnline) {
    if (_context == null || !_context!.mounted) return;

    final sessionService = Provider.of<SessionService>(_context!, listen: false);
    
    if (!isOnline) {
      // Çevrimdışı duruma geçiş
      _handleOfflineTransition(sessionService);
    } else {
      // Çevrimiçi duruma geçiş
      _handleOnlineTransition(sessionService);
    }
  }

  /// Çevrimdışı duruma geçiş işlemleri
  void _handleOfflineTransition(SessionService sessionService) {
    if (_context == null || !_context!.mounted) return;

    _wasActuallyOffline = true; // Mark that we are genuinely offline

    // Eğer kullanıcı giriş yapmışsa ve çevrimdışı olursa, misafir moduna geçiş seçeneği sun
    if (!sessionService.isGuest) {
      _showOfflineTransitionDialog();
    }
  }

  /// Çevrimdışı geçiş dialog'u
  void _showOfflineTransitionDialog() {
    if (_context == null || !_context!.mounted) return;

    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Bağlantı Kesildi'),
          ],
        ),
        content: const Text(
          'İnternet bağlantınız kesildi. Misafir modunda devam etmek ister misiniz?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              final sessionService = Provider.of<SessionService>(_context!, listen: false);
              await _autoSignInAsGuest(sessionService);
              _wasOfflineAsGuest = true;
            },
            icon: const Icon(Icons.person),
            label: const Text('Misafir Modunda Devam Et'),
          ),
        ],
      ),
    );
  }

  /// Çevrimiçi duruma geçiş işlemleri
  void _handleOnlineTransition(SessionService sessionService) {
    if (_context == null || !_context!.mounted) return;

    // Skip notification on initial connection
    if (_isInitialConnection) {
      _isInitialConnection = false;
      return;
    }

    // Only show reconnection notification if we were actually offline
    if (_wasActuallyOffline) {
      _wasActuallyOffline = false; // Reset the flag
      _showConnectionRestoredNotification();
    }

    // Eğer çevrimdışıyken misafir moduna geçmişse, kullanıcıya seçenek sun
    if (_wasOfflineAsGuest && sessionService.isGuest) {
      _showOnlineTransitionDialog();
      _wasOfflineAsGuest = false;
    }
  }

  /// Otomatik misafir girişi
  Future<void> _autoSignInAsGuest(SessionService sessionService) async {
    try {
      await sessionService.signInAsGuest();
      
      if (_context != null && _context!.mounted) {
        ScaffoldMessenger.of(_context!).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('İnternet bağlantısı yok. Misafir modunda devam ediyorsunuz.')),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Otomatik misafir girişi başarısız: $e');
    }
  }

  /// Çevrimiçi geçiş dialog'u
  void _showOnlineTransitionDialog() {
    if (_context == null || !_context!.mounted) return;

    showDialog(
      context: _context!,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wifi, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Bağlantı Geri Geldi'),
          ],
        ),
        content: const Text(
          'İnternet bağlantınız geri geldi! Google hesabınızla giriş yaparak tüm özelliklerden yararlanabilirsiniz.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Misafir Modunda Devam Et'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _signOutAndShowSignIn();
            },
            icon: const Icon(Icons.login),
            label: const Text('Google ile Giriş Yap'),
          ),
        ],
      ),
    );
  }

  /// Çıkış yap ve giriş ekranını göster
  Future<void> _signOutAndShowSignIn() async {
    if (_context == null || !_context!.mounted) return;

    final sessionService = Provider.of<SessionService>(_context!, listen: false);
    await sessionService.signOut();
  }

  /// Bağlantı geri geldi bildirimi
  void _showConnectionRestoredNotification() {
    if (_context == null || !_context!.mounted) return;

    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi, color: Colors.white),
            SizedBox(width: 12),
            Text('İnternet bağlantısı geri geldi'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Servisin durumunu temizle
  void dispose() {
    stopMonitoring();
    _wasOfflineAsGuest = false;
    _wasActuallyOffline = false; // Reset offline tracking
    _isInitialConnection = true; // Reset for next initialization
  }
}