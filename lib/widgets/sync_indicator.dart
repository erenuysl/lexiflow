// lib/widgets/sync_indicator.dart
// Sync indicator widget with Turkish tooltips

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_status_provider.dart';
import '../services/cloud_sync_service.dart';

/// Sync Indicator Widget
/// Shows sync status with colored icons and Turkish tooltips
class SyncIndicator extends StatelessWidget {
  final double size;
  final bool showText;
  
  const SyncIndicator({
    Key? key,
    this.size = 16.0,
    this.showText = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Consumer<SyncStatusProvider>(
      builder: (context, syncProvider, child) {
        final status = syncProvider.syncStatus;
        final statusText = syncProvider.getStatusText();
        final statusIcon = syncProvider.getStatusIcon();
        
        Widget indicator = Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(status),
          ),
          child: Center(
            child: Text(
              statusIcon,
              style: TextStyle(
                fontSize: size * 0.6,
                color: Colors.white,
              ),
            ),
          ),
        );
        
        if (showText) {
          indicator = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              indicator,
              const SizedBox(width: 8),
              Text(
                statusText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }
        
        return Tooltip(
          message: statusText,
          child: GestureDetector(
            onTap: () => _onTap(context, syncProvider),
            child: indicator,
          ),
        );
      },
    );
  }
  
  Color _getStatusColor(CloudSyncStatus status) {
    switch (status) {
      case CloudSyncStatus.synced:
        return Colors.green;
      case CloudSyncStatus.syncing:
        return Colors.orange;
      case CloudSyncStatus.offline:
        return Colors.red;
      case CloudSyncStatus.online:
        return Colors.green;
      case CloudSyncStatus.error:
        return Colors.red.shade700;
    }
  }
  
  void _onTap(BuildContext context, SyncStatusProvider syncProvider) {
    if (syncProvider.syncStatus == CloudSyncStatus.offline) {
      // offline durumda bilgi göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İnternet bağlantısı yok. Veriler yerel olarak kaydediliyor.'),
          duration: Duration(seconds: 2),
        ),
      );
    } else if (syncProvider.syncStatus == CloudSyncStatus.error) {
      // hata durumunda yeniden dene
      syncProvider.forceSync();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senkronizasyon yeniden deneniyor...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Compact sync indicator for app bars
class CompactSyncIndicator extends StatelessWidget {
  const CompactSyncIndicator({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 8.0),
      child: SyncIndicator(size: 12.0),
    );
  }
}

/// Full sync status widget for settings or profile
class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Consumer<SyncStatusProvider>(
      builder: (context, syncProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SyncIndicator(size: 20.0),
                    const SizedBox(width: 12),
                    Text(
                      'Senkronizasyon Durumu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  syncProvider.getStatusText(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (syncProvider.syncStatus == CloudSyncStatus.error) ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => syncProvider.forceSync(),
                    child: const Text('Yeniden Dene'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}