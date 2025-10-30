import 'package:flutter/material.dart';
import '../services/sync_manager.dart';
import '../utils/app_icons.dart';

/// Offline durumunu gösteren ve senkronizasyon bilgilerini içeren widget
class OfflineIndicator extends StatelessWidget {
  final bool compact;
  
  const OfflineIndicator({
    super.key, 
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncStatus>(
      stream: SyncManager().syncStatusStream,
      builder: (context, snapshot) {
        final syncStatus = snapshot.data ?? SyncStatus.completed;
        
        // Compact modda sadece pending ve inProgress durumlarında göster
        if (compact && syncStatus == SyncStatus.completed) {
          return const SizedBox.shrink();
        }
        
        // Full modda tüm durumları göster
        return _buildIndicator(context, syncStatus);
      }
    );
  }
  
  Widget _buildIndicator(BuildContext context, SyncStatus status) {
    // Durum bazlı renk ve metin belirleme
    Color color;
    String text;
    IconData icon;
    
    switch (status) {
      case SyncStatus.pending:
        color = Colors.red;
        text = compact ? 'Çevrimdışı' : 'Çevrimdışı - Değişiklikler daha sonra senkronize edilecek';
        icon = AppIcons.wifiOff;
        break;
      case SyncStatus.inProgress:
        color = Colors.amber;
        text = compact ? 'Senkronize ediliyor' : 'Değişiklikler senkronize ediliyor...';
        icon = AppIcons.refresh;
        break;
      case SyncStatus.completed:
      default:
        color = Colors.green;
        text = 'Çevrimiçi - Tüm değişiklikler senkronize edildi';
        icon = AppIcons.wifiCheck;
        break;
    }
    
    if (compact) {
      // Kompakt mod - sadece küçük bir gösterge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      );
    }
    
    // Tam mod - daha fazla bilgi içeren banner
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
          if (status == SyncStatus.pending)
            StreamBuilder<int>(
              stream: SyncManager().pendingOperationsStream.map((ops) => ops.length),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count > 0) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
            ),
        ],
      ),
    );
  }
}