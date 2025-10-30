// lib/widgets/error_handler_widget.dart
// Comprehensive error handling widget for user feedback

import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/design_system.dart';
import '../utils/logger.dart';

/// Farklı senaryolar için hata türleri
enum ErrorType {
  network,
  timeout,
  validation,
  authentication,
  permission,
  unknown,
}

/// Hata önem seviyeleri
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Hata veri modeli
class ErrorData {
  final ErrorType type;
  final ErrorSeverity severity;
  final String message;
  final String? details;
  final String? actionLabel;
  final VoidCallback? onAction;
  final DateTime timestamp;

  ErrorData({
    required this.type,
    required this.severity,
    required this.message,
    this.details,
    this.actionLabel,
    this.onAction,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Hata türü için uygun ikonu al
  IconData get icon {
    switch (type) {
      case ErrorType.network:
        return Icons.wifi_off;
      case ErrorType.timeout:
        return Icons.access_time;
      case ErrorType.validation:
        return Icons.error_outline;
      case ErrorType.authentication:
        return Icons.lock_outline;
      case ErrorType.permission:
        return Icons.security;
      case ErrorType.unknown:
        return Icons.help_outline;
    }
  }

  /// Hata önem seviyesi için uygun rengi al
  Color getColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (severity) {
      case ErrorSeverity.low:
        return AppColors.warning;
      case ErrorSeverity.medium:
        return AppColors.error;
      case ErrorSeverity.high:
        return AppColors.error;
      case ErrorSeverity.critical:
        return theme.colorScheme.error;
    }
  }
}

/// Comprehensive error handler widget
class ErrorHandlerWidget extends StatefulWidget {
  final ErrorData error;
  final bool showDetails;
  final bool dismissible;
  final VoidCallback? onDismiss;
  final EdgeInsetsGeometry? padding;

  const ErrorHandlerWidget({
    super.key,
    required this.error,
    this.showDetails = false,
    this.dismissible = true,
    this.onDismiss,
    this.padding,
  });

  @override
  State<ErrorHandlerWidget> createState() => _ErrorHandlerWidgetState();
}

class _ErrorHandlerWidgetState extends State<ErrorHandlerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _showDetails = false;

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
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _showDetails = widget.showDetails;
    _animationController.forward();
    
    // Log error for debugging
    Logger.e(
      'Error displayed: ${widget.error.message}',
      widget.error.details,
      null,
      'ErrorHandlerWidget',
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildErrorCard(context),
          ),
        );
      },
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = widget.error.getColor(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive design
    final isSmallScreen = screenWidth < 768;
    final cardPadding = isSmallScreen ? 12.0 : 16.0;
    final iconSize = isSmallScreen ? 20.0 : 24.0;
    
    return Container(
      margin: widget.padding ?? EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errorColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: errorColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                // Error icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.error.icon,
                    color: errorColor,
                    size: iconSize,
                  ),
                ),
                
                SizedBox(width: 16),
                
                // Error message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.error.message,
                        style: isSmallScreen 
                            ? AppTextStyles.body2.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              )
                            : AppTextStyles.title3.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                      ),
                      
                      if (widget.error.severity == ErrorSeverity.critical)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Kritik Hata',
                            style: AppTextStyles.body3.copyWith(
                              color: errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Details toggle
                    if (widget.error.details != null)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showDetails = !_showDetails;
                          });
                        },
                        icon: Icon(
                          _showDetails ? Icons.expand_less : Icons.expand_more,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        iconSize: iconSize,
                        constraints: BoxConstraints(
                          minWidth: isSmallScreen ? 32 : 40,
                          minHeight: isSmallScreen ? 32 : 40,
                        ),
                      ),
                    
                    // Dismiss button
                    if (widget.dismissible)
                      IconButton(
                        onPressed: _dismiss,
                        icon: Icon(
                          Icons.close,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        iconSize: iconSize,
                        constraints: BoxConstraints(
                          minWidth: isSmallScreen ? 32 : 40,
                          minHeight: isSmallScreen ? 32 : 40,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Details section
          if (_showDetails && widget.error.details != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                cardPadding,
                0,
                cardPadding,
                cardPadding,
              ),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  widget.error.details!,
                  style: AppTextStyles.body3.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          
          // Action button
          if (widget.error.onAction != null && widget.error.actionLabel != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                cardPadding,
                0,
                cardPadding,
                cardPadding,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.error.onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: errorColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.error.actionLabel!,
                    style: isSmallScreen 
                        ? AppTextStyles.body2.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          )
                        : AppTextStyles.title3.copyWith(
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }
}

/// Error handler overlay for global error display
class ErrorHandlerOverlay {
  static OverlayEntry? _currentOverlay;

  /// Show error overlay
  static void showError(
    BuildContext context,
    ErrorData error, {
    Duration? duration,
  }) {
    // Remove existing overlay
    hideError();

    final overlay = Overlay.of(context);
    
    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: ErrorHandlerWidget(
            error: error,
            onDismiss: hideError,
          ),
        ),
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto-dismiss after duration
    if (duration != null) {
      Timer(duration, hideError);
    }
  }

  /// Hide error overlay
  static void hideError() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Show network error
  static void showNetworkError(BuildContext context) {
    showError(
      context,
      ErrorData(
        type: ErrorType.network,
        severity: ErrorSeverity.medium,
        message: 'İnternet bağlantısı bulunamadı',
        details: 'Lütfen internet bağlantınızı kontrol edin ve tekrar deneyin.',
        actionLabel: 'Tekrar Dene',
        onAction: () {
          hideError();
          // Retry logic can be implemented here
        },
      ),
      duration: const Duration(seconds: 5),
    );
  }

  /// Show timeout error
  static void showTimeoutError(BuildContext context) {
    showError(
      context,
      ErrorData(
        type: ErrorType.timeout,
        severity: ErrorSeverity.medium,
        message: 'İstek zaman aşımına uğradı',
        details: 'Sunucu yanıt vermedi. Lütfen tekrar deneyin.',
        actionLabel: 'Tekrar Dene',
        onAction: hideError,
      ),
      duration: const Duration(seconds: 4),
    );
  }

  /// Show validation error
  static void showValidationError(
    BuildContext context,
    String message, {
    String? details,
  }) {
    showError(
      context,
      ErrorData(
        type: ErrorType.validation,
        severity: ErrorSeverity.low,
        message: message,
        details: details,
      ),
      duration: const Duration(seconds: 3),
    );
  }
}