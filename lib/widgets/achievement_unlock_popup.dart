import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../models/achievement.dart';
import '../utils/design_system.dart';
import '../utils/animation_utils.dart';

class AchievementUnlockPopup extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback? onComplete;

  const AchievementUnlockPopup({
    super.key,
    required this.achievement,
    this.onComplete,
  });

  @override
  State<AchievementUnlockPopup> createState() => _AchievementUnlockPopupState();
}

class _AchievementUnlockPopupState extends State<AchievementUnlockPopup>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late ConfettiController _confettiController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Slide animation (from top)
    _slideController = AnimationUtils.createSafeController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Scale animation (bounce effect)
    _scaleController = AnimationUtils.createSafeController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Fade animation (for exit)
    _fadeController = AnimationUtils.createSafeController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Confetti controller
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    // Create animations
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.bounceOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimationSequence() async {
    // Start confetti immediately
    _confettiController.play();

    // Start slide animation
    await _slideController.forward();

    // Start scale animation with slight delay
    await Future.delayed(const Duration(milliseconds: 100));
    await _scaleController.forward();

    // Wait for display duration
    await Future.delayed(const Duration(milliseconds: 2000));

    // Start fade out
    await _fadeController.forward();

    // Complete callback
    if (widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scaleController.dispose();
    _fadeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? AppDarkColors.primaryGradient : AppColors.primaryGradient;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Confetti animation
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 1.57, // radians - 90 degrees (downward)
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.3,
              numberOfParticles: 15,
              gravity: 0.3,
              shouldLoop: false,
              colors: [
                colors[0],
                colors[1],
                isDark ? AppDarkColors.success : AppColors.success,
                isDark ? AppDarkColors.warning : AppColors.warning,
                isDark ? AppDarkColors.secondary : AppColors.secondary,
              ],
            ),
          ),

          // Main popup
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 20,
            right: 20,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _slideAnimation,
                _scaleAnimation,
                _fadeAnimation,
              ]),
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: _buildPopupContent(context, isDark, colors),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupContent(BuildContext context, bool isDark, List<Color> colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors[0].withOpacity(0.95),
            colors[1].withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Achievement icon with glow effect
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              widget.achievement.icon,
              size: 32,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            'Başarım Kazanıldı!',
            style: AppTextStyles.headline3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Achievement title with emoji
          Text(
            '🔥 ${widget.achievement.title}',
            style: AppTextStyles.body1.copyWith(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          // XP reward
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '+${widget.achievement.xpReward} XP',
                  style: AppTextStyles.body2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}