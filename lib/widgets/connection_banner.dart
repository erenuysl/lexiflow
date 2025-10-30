import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/design_system.dart';
import '../utils/app_icons.dart';

/// Material 3 tasarımı ile yeniden kullanılabilir bağlantı banner widget'ı
/// Bağlantı durumu ve offline/online mesajlarını göstermek için kullanılır
class ConnectionBanner extends StatelessWidget {
  final ConnectionBannerType type;
  final String? customTitle;
  final String? customMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showCloseButton;
  final bool persistent;
  final EdgeInsets? margin;

  const ConnectionBanner({
    super.key,
    required this.type,
    this.customTitle,
    this.customMessage,
    this.onRetry,
    this.onDismiss,
    this.showCloseButton = true,
    this.persistent = false,
    this.margin,
  });

  /// Offline banner için factory constructor
  factory ConnectionBanner.offline({
    String? title,
    String? message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    bool showCloseButton = true,
    EdgeInsets? margin,
  }) {
    return ConnectionBanner(
      type: ConnectionBannerType.offline,
      customTitle: title,
      customMessage: message,
      onRetry: onRetry,
      onDismiss: onDismiss,
      showCloseButton: showCloseButton,
      margin: margin,
    );
  }

  /// Online banner için factory constructor
  factory ConnectionBanner.online({
    String? title,
    String? message,
    VoidCallback? onDismiss,
    bool showCloseButton = true,
    EdgeInsets? margin,
  }) {
    return ConnectionBanner(
      type: ConnectionBannerType.online,
      customTitle: title,
      customMessage: message,
      onDismiss: onDismiss,
      showCloseButton: showCloseButton,
      margin: margin,
    );
  }

  /// Uyarı banner'ı için factory constructor
  factory ConnectionBanner.warning({
    String? title,
    String? message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    bool showCloseButton = true,
    EdgeInsets? margin,
  }) {
    return ConnectionBanner(
      type: ConnectionBannerType.warning,
      customTitle: title,
      customMessage: message,
      onRetry: onRetry,
      onDismiss: onDismiss,
      showCloseButton: showCloseButton,
      margin: margin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final config = _getConfigForType(type, isDark);

    return Container(
      margin: margin ?? const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: AppBorderRadius.large,
        border: Border.all(
          color: config.borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: config.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: config.iconBackgroundColor,
              borderRadius: AppBorderRadius.medium,
            ),
            child: Icon(
              config.icon,
              color: config.iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  customTitle ?? config.defaultTitle,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: config.titleColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                
                // Message
                Text(
                  customMessage ?? config.defaultMessage,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: config.messageColor,
                    height: 1.3,
                  ),
                ),
                
                // Action buttons
                if (onRetry != null || type == ConnectionBannerType.offline) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (onRetry != null)
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: Icon(
                            Icons.refresh_rounded,
                            size: 18,
                            color: config.actionColor,
                          ),
                          label: Text(
                            'Tekrar Dene',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: config.actionColor,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            backgroundColor: config.actionBackgroundColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppBorderRadius.medium,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          // Close button
          if (showCloseButton && onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close_rounded,
                color: config.closeButtonColor,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              style: IconButton.styleFrom(
                backgroundColor: config.closeButtonBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: AppBorderRadius.small,
                ),
              ),
            ),
        ],
      ),
    );
  }

  _BannerConfig _getConfigForType(ConnectionBannerType type, bool isDark) {
    switch (type) {
      case ConnectionBannerType.offline:
        return _BannerConfig(
          icon: AppIcons.wifiOff,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.red.shade600,
          backgroundColor: isDark 
            ? Colors.red.shade900.withOpacity(0.2)
            : Colors.red.shade50,
          borderColor: Colors.red.shade300,
          shadowColor: Colors.red.withOpacity(0.15),
          titleColor: isDark ? Colors.red.shade200 : Colors.red.shade800,
          messageColor: isDark ? Colors.red.shade300 : Colors.red.shade700,
          actionColor: Colors.red.shade600,
          actionBackgroundColor: isDark 
            ? Colors.red.shade800.withOpacity(0.3)
            : Colors.red.shade100,
          closeButtonColor: isDark ? Colors.red.shade300 : Colors.red.shade600,
          closeButtonBackgroundColor: isDark 
            ? Colors.red.shade800.withOpacity(0.3)
            : Colors.red.shade100,
          defaultTitle: 'Bağlantı Yok',
          defaultMessage: 'İnternet bağlantınızı kontrol edin ve tekrar deneyin.',
        );
        
      case ConnectionBannerType.online:
        return _BannerConfig(
          icon: AppIcons.wifiCheck,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.green.shade600,
          backgroundColor: isDark 
            ? Colors.green.shade900.withOpacity(0.2)
            : Colors.green.shade50,
          borderColor: Colors.green.shade300,
          shadowColor: Colors.green.withOpacity(0.15),
          titleColor: isDark ? Colors.green.shade200 : Colors.green.shade800,
          messageColor: isDark ? Colors.green.shade300 : Colors.green.shade700,
          actionColor: Colors.green.shade600,
          actionBackgroundColor: isDark 
            ? Colors.green.shade800.withOpacity(0.3)
            : Colors.green.shade100,
          closeButtonColor: isDark ? Colors.green.shade300 : Colors.green.shade600,
          closeButtonBackgroundColor: isDark 
            ? Colors.green.shade800.withOpacity(0.3)
            : Colors.green.shade100,
          defaultTitle: 'Bağlantı Geri Geldi',
          defaultMessage: 'Tüm özellikler tekrar kullanılabilir.',
        );
        
      case ConnectionBannerType.warning:
        return _BannerConfig(
          icon: Icons.warning_rounded,
          iconColor: Colors.white,
          iconBackgroundColor: Colors.amber.shade600,
          backgroundColor: isDark 
            ? Colors.amber.shade900.withOpacity(0.2)
            : Colors.amber.shade50,
          borderColor: Colors.amber.shade300,
          shadowColor: Colors.amber.withOpacity(0.15),
          titleColor: isDark ? Colors.amber.shade200 : Colors.amber.shade800,
          messageColor: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
          actionColor: Colors.amber.shade600,
          actionBackgroundColor: isDark 
            ? Colors.amber.shade800.withOpacity(0.3)
            : Colors.amber.shade100,
          closeButtonColor: isDark ? Colors.amber.shade300 : Colors.amber.shade600,
          closeButtonBackgroundColor: isDark 
            ? Colors.amber.shade800.withOpacity(0.3)
            : Colors.amber.shade100,
          defaultTitle: 'Uyarı',
          defaultMessage: 'Bağlantı sorunları yaşanıyor.',
        );
    }
  }
}

/// Configuration class for banner styling
class _BannerConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final Color titleColor;
  final Color messageColor;
  final Color actionColor;
  final Color actionBackgroundColor;
  final Color closeButtonColor;
  final Color closeButtonBackgroundColor;
  final String defaultTitle;
  final String defaultMessage;

  const _BannerConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
    required this.titleColor,
    required this.messageColor,
    required this.actionColor,
    required this.actionBackgroundColor,
    required this.closeButtonColor,
    required this.closeButtonBackgroundColor,
    required this.defaultTitle,
    required this.defaultMessage,
  });
}

/// Types of connection banners
enum ConnectionBannerType {
  offline,
  online,
  warning,
}