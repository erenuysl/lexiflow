import 'package:flutter/material.dart';

enum ToastType {
  success,
  error,
  info,
}

class LexiflowToast extends StatefulWidget {
  final ToastType type;
  final String message;
  final VoidCallback? onDismiss;

  const LexiflowToast({
    super.key,
    required this.type,
    required this.message,
    this.onDismiss,
  });

  @override
  State<LexiflowToast> createState() => _LexiflowToastState();
}

class _LexiflowToastState extends State<LexiflowToast>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    // Start the animation
    _animationController.forward();

    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _animationController.reverse();
    if (mounted && widget.onDismiss != null) {
      widget.onDismiss!();
    }
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: widget.type == ToastType.success
                      ? [const Color(0xFF00C851), const Color(0xFF007E33)]
                      : widget.type == ToastType.error
                          ? [const Color(0xFFCC0000), const Color(0xFFFF4444)]
                          : [const Color(0xFF4285F4), const Color(0xFF34AADC)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.type == ToastType.success
                        ? Icons.check_circle
                        : widget.type == ToastType.error
                            ? Icons.error
                            : Icons.info_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToastOverlay {
  static OverlayEntry? _currentOverlay;

  static void show(BuildContext context, ToastType type, String message) {
    // Remove any existing toast
    _currentOverlay?.remove();

    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 80, // Above navigation bar
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: LexiflowToast(
              type: type,
              message: message,
              onDismiss: () {
                _currentOverlay?.remove();
                _currentOverlay = null;
              },
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

/// Show a Lexiflow-style toast notification
/// 
/// [context] - BuildContext for overlay insertion
/// [type] - Type of toast (success, error, info)
/// [message] - Message to display
void showLexiflowToast(BuildContext context, ToastType type, String message) {
  _ToastOverlay.show(context, type, message);
}

/// Hide any currently showing toast
void hideLexiflowToast() {
  _ToastOverlay.hide();
}