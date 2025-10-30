import 'package:flutter/material.dart';
import '../utils/design_system.dart';

class LoadingNotification extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onComplete;
  final Color? backgroundColor;
  final double opacity;

  const LoadingNotification({
    super.key,
    required this.message,
    this.duration = const Duration(seconds: 3),
    this.onComplete,
    this.backgroundColor,
    this.opacity = 0.9,
  });

  @override
  State<LoadingNotification> createState() => _LoadingNotificationState();
}

class _LoadingNotificationState extends State<LoadingNotification>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late AnimationController _pulseController;
  
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Setup animations
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: widget.opacity,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start animations
    _startAnimations();
  }

  void _startAnimations() async {
    // Start entrance animations
    _slideController.forward();
    _fadeController.forward();
    _pulseController.repeat(reverse: true);
    
    // Start progress animation
    _progressController.forward();
    
    // Auto-dismiss after duration
    await Future.delayed(widget.duration);
    
    if (mounted) {
      await _dismiss();
    }
  }

  Future<void> _dismiss() async {
    _pulseController.stop();
    
    // Exit animations
    await Future.wait([
      _slideController.reverse(),
      _fadeController.reverse(),
    ]);
    
    if (widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive breakpoints
    final isSmallScreen = screenWidth <= 320;
    final isMediumScreen = screenWidth > 320 && screenWidth <= 768;
    
    // Responsive values
    final topPadding = MediaQuery.of(context).padding.top + (isSmallScreen ? 12 : 16);
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    final maxWidth = isSmallScreen ? double.infinity : isMediumScreen ? 380.0 : 400.0;
    final contentPadding = isSmallScreen ? AppSpacing.md : AppSpacing.lg;
    final iconSize = isSmallScreen ? 32.0 : 40.0;
    final loadingSize = isSmallScreen ? 16.0 : 20.0;
    
    return Positioned(
      top: topPadding,
      left: horizontalPadding,
      right: horizontalPadding,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
              ),
              margin: screenWidth > 600 
                  ? EdgeInsets.symmetric(horizontal: (screenWidth - maxWidth) / 2)
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? 
                    (isDark ? AppDarkColors.surface : AppColors.surface),
                borderRadius: AppBorderRadius.large,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress bar
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Container(
                        height: isSmallScreen ? 3 : 4,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progressAnimation.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Content
                  Padding(
                    padding: EdgeInsets.all(contentPadding),
                    child: Row(
                      children: [
                        // Loading indicator
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: iconSize,
                                height: iconSize,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      theme.colorScheme.primary,
                                      theme.colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: AppBorderRadius.medium,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: loadingSize,
                                    height: loadingSize,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        
                        SizedBox(width: isSmallScreen ? AppSpacing.sm : AppSpacing.md),
                        
                        // Message
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.message,
                                style: (isSmallScreen ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? AppSpacing.xs / 2 : AppSpacing.xs),
                              Text(
                                'Lütfen bekleyin...',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Close button (optional)
                        IconButton(
                          onPressed: _dismiss,
                          icon: Icon(
                            Icons.close_rounded,
                            size: isSmallScreen ? 18 : 20,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: isSmallScreen ? 28 : 32,
                            minHeight: isSmallScreen ? 28 : 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Overlay helper for showing notifications
class LoadingNotificationOverlay {
  static OverlayEntry? _currentOverlay;

  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    Color? backgroundColor,
    double opacity = 0.9,
    VoidCallback? onComplete,
  }) {
    // Remove existing overlay if any
    hide();

    final overlay = Overlay.of(context);
    _currentOverlay = OverlayEntry(
      builder: (context) => LoadingNotification(
        message: message,
        duration: duration,
        backgroundColor: backgroundColor,
        opacity: opacity,
        onComplete: () {
          hide();
          onComplete?.call();
        },
      ),
    );

    overlay.insert(_currentOverlay!);
  }

  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}