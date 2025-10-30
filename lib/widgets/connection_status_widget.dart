import 'package:flutter/material.dart';
import '../services/sync_manager.dart';
import '../services/connectivity_service.dart';
import '../utils/design_system.dart';
import '../utils/app_icons.dart';

/// Bağlantı durumu bildirimlerini gösteren ve bağlantı değişikliklerini yöneten widget
class ConnectionStatusWidget extends StatefulWidget {
  final Widget child;
  final bool showPersistentIndicator;
  
  const ConnectionStatusWidget({
    super.key,
    required this.child,
    this.showPersistentIndicator = true,
  });

  @override
  State<ConnectionStatusWidget> createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isOnline = true; // Start with true to prevent false initial notification
  bool _isInitialConnection = true; // Flag to skip first connectivity event
  bool _wasActuallyOffline = false; // Track if we were genuinely offline
  SyncStatus _syncStatus = SyncStatus.completed;
  bool _showNotification = false;

  @override
  void initState() {
    super.initState();
    
    // Animation controllers
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    // Listen to connectivity status changes using ConnectivityService
    ConnectivityService().onlineStatusStream.listen((isOnline) {
      if (mounted) {
        final wasOnline = _isOnline;
        
        // Skip the first connectivity event to prevent false initial notification
        if (_isInitialConnection) {
          _isInitialConnection = false;
          setState(() {
            _isOnline = isOnline;
            _syncStatus = isOnline ? SyncStatus.completed : SyncStatus.pending;
          });
          return;
        }
        
        setState(() {
          _isOnline = isOnline;
          // Map connectivity to sync status for backward compatibility
          _syncStatus = isOnline ? SyncStatus.completed : SyncStatus.pending;
        });
        
        if (wasOnline && !isOnline) {
          _wasActuallyOffline = true; // Mark that we were genuinely offline
          _showConnectionLostNotification();
        } else if (!wasOnline && isOnline && _wasActuallyOffline) {
          _wasActuallyOffline = false; // Reset the flag
          _showConnectionRestoredNotification();
        }
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _showConnectionLostNotification() {
    setState(() {
      _showNotification = true;
    });
    
    _slideController.forward();
    _fadeController.forward();
    
    // Auto-hide after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_isOnline) {
        _hideNotification();
      }
    });
  }

  void _showConnectionRestoredNotification() {
    setState(() {
      _showNotification = true;
    });
    
    _slideController.forward();
    _fadeController.forward();
    
    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _hideNotification();
      }
    });
  }

  void _hideNotification() {
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showNotification = false;
        });
        _fadeController.reset();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          
          // Connection status notification
          if (_showNotification)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(AppSpacing.md),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: _isOnline 
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                        borderRadius: AppBorderRadius.large,
                        boxShadow: [
                          BoxShadow(
                            color: (_isOnline ? Colors.green : Colors.red)
                                .withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isOnline 
                              ? AppIcons.wifiCheck 
                              : AppIcons.wifiOff,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isOnline 
                                    ? 'Bağlantı Geri Geldi' 
                                    : 'Bağlantı Kesildi',
                                  style: AppTextStyles.title3.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isOnline
                                    ? 'Tüm özellikler tekrar kullanılabilir'
                                    : 'Çevrimdışı modda çalışıyorsunuz',
                                  style: AppTextStyles.body2.copyWith(
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _hideNotification,
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Persistent offline indicator
          if (widget.showPersistentIndicator && _syncStatus == SyncStatus.pending && !_showNotification)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  color: Colors.red.shade600,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        AppIcons.wifiOff,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Çevrimdışı',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Global connection status manager for showing notifications
class ConnectionStatusManager {
  static OverlayEntry? _currentOverlay;
  
  static void showConnectionLostDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppBorderRadius.large,
        ),
        title: Row(
          children: [
            Icon(
              AppIcons.wifiOff,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Bağlantı Kesildi',
              style: AppTextStyles.title2.copyWith(
                color: Colors.red.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İnternet bağlantınız kesildi. Uygulama çevrimdışı modda çalışmaya devam edecek.',
              style: AppTextStyles.body1.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: AppBorderRadius.medium,
                border: Border.all(
                  color: Colors.amber.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Bazı özellikler sınırlı olabilir',
                      style: AppTextStyles.body2.copyWith(
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Tamam',
              style: AppTextStyles.button.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}