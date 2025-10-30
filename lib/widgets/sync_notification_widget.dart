// lib/widgets/sync_notification_widget.dart
// Widget for showing sync status notifications and progress indicators

import 'package:flutter/material.dart';
import '../services/sync_manager.dart';

class SyncNotificationWidget extends StatefulWidget {
  const SyncNotificationWidget({super.key});

  @override
  State<SyncNotificationWidget> createState() => _SyncNotificationWidgetState();
}

class _SyncNotificationWidgetState extends State<SyncNotificationWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  SyncStatus? _lastStatus;
  bool _isVisible = false;
  DateTime? _lastSyncMessageTime;
  static const Duration _messageCooldown = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _shouldShowMessage(SyncStatus status) {
    // Don't show message if we're already showing one
    if (_isVisible) return false;
    
    // Don't show message if we recently showed one (cooldown period)
    if (_lastSyncMessageTime != null) {
      final timeSinceLastMessage = DateTime.now().difference(_lastSyncMessageTime!);
      if (timeSinceLastMessage < _messageCooldown) {
        return false;
      }
    }
    
    // Only show completed message when actually transitioning from in-progress
    if (status == SyncStatus.completed) {
      return _lastStatus == SyncStatus.inProgress;
    }
    
    // Show other status changes normally
    return _lastStatus != status && _lastStatus != null;
  }

  void _showNotification() {
    if (!mounted) return;
    
    setState(() {
      _isVisible = true;
      _lastSyncMessageTime = DateTime.now();
    });
    _animationController.forward();
    
    // Auto-hide after 3 seconds for completed status, 5 seconds for others
    final duration = _lastStatus == SyncStatus.completed 
        ? const Duration(seconds: 3)
        : const Duration(seconds: 5);
        
    Future.delayed(duration, () {
      _hideNotification();
    });
  }

  void _hideNotification() {
    if (!mounted || !_isVisible) return;
    
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
      }
    });
  }

  Widget _buildNotificationContent(SyncStatus status) {
    IconData icon;
    Color backgroundColor;
    Color iconColor;
    String message;
    Widget? trailing;

    switch (status) {
      case SyncStatus.pending:
        icon = Icons.cloud_off;
        backgroundColor = Colors.orange.shade100;
        iconColor = Colors.orange.shade700;
        message = 'Çevrimdışı - Senkronizasyon bekliyor';
        break;
        
      case SyncStatus.inProgress:
        icon = Icons.cloud_sync;
        backgroundColor = Colors.blue.shade100;
        iconColor = Colors.blue.shade700;
        message = 'Senkronizasyon devam ediyor...';
        trailing = SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
          ),
        );
        break;
        
      case SyncStatus.completed:
        icon = Icons.cloud_done;
        backgroundColor = Colors.green.shade100;
        iconColor = Colors.green.shade700;
        message = 'Senkronizasyon tamamlandı';
        break;
        
      case SyncStatus.failed:
        icon = Icons.cloud_off;
        backgroundColor = Colors.red.shade100;
        iconColor = Colors.red.shade700;
        message = 'Senkronizasyon başarısız';
        trailing = IconButton(
          icon: Icon(Icons.refresh, size: 16, color: iconColor),
          onPressed: () {
            SyncManager().forceSyncAttempt();
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
        );
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncManager().syncStatusStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final currentStatus = snapshot.data!;
        
        // Show notification for status changes with proper validation
        if (_lastStatus != currentStatus) {
          final previousStatus = _lastStatus;
          _lastStatus = currentStatus;
          
          // Use the new shouldShowMessage logic
          if (_shouldShowMessage(currentStatus)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showNotification();
            });
          }
        }

        if (!_isVisible) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildNotificationContent(currentStatus),
            ),
          ),
        );
      },
    );
  }
}