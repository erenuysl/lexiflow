// lib/utils/animation_utils.dart
// Safe Animation Helpers for WordFlow

import 'package:flutter/material.dart';

class AnimationUtils {
  // Safe opacity getter with bounds checking
  static double getSafeOpacity(double value) {
    return value.clamp(0.0, 1.0);
  }

  // Safe scale getter with bounds checking
  static double getSafeScale(double value) {
    return value.clamp(0.0, 2.0);
  }

  // Safe translation getter with bounds checking
  static Offset getSafeTranslation(double value, double maxOffset) {
    final clampedValue = value.clamp(0.0, 1.0);
    return Offset(0, maxOffset * (1 - clampedValue));
  }

  static AnimationController createSafeController({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 300),
    double lowerBound = 0.0,
    double upperBound = 1.0,
  }) {
    final controller = AnimationController(
      vsync: vsync,
      duration: duration,
      lowerBound: lowerBound,
      upperBound: upperBound,
    );

    // Add bounds checking listener
    controller.addListener(() {
      if (controller.value < lowerBound) {
        controller.value = lowerBound;
      }
      if (controller.value > upperBound) {
        controller.value = upperBound;
      }
    });

    return controller;
  }

  // Safe animation builder
  static Widget buildSafeAnimation({
    required Animation<double> animation,
    required Widget Function(BuildContext context, double value, Widget? child)
    builder,
    Widget? child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final safeValue = getSafeOpacity(animation.value);
        return builder(context, safeValue, child);
      },
    );
  }

  // Safe fade transition
  static Widget buildSafeFadeTransition({
    required Animation<double> animation,
    required Widget child,
  }) {
    return FadeTransition(opacity: animation, child: child);
  }

  // Safe scale transition
  static Widget buildSafeScaleTransition({
    required Animation<double> animation,
    required Widget child,
  }) {
    return ScaleTransition(scale: animation, child: child);
  }

  // Safe slide transition
  static Widget buildSafeSlideTransition({
    required Animation<double> animation,
    required Widget child,
    Offset begin = const Offset(0, 1),
    Offset end = Offset.zero,
  }) {
    return SlideTransition(
      position: Tween<Offset>(begin: begin, end: end).animate(animation),
      child: child,
    );
  }

  // Safe transform translate
  static Widget buildSafeTransformTranslate({
    required Animation<double> animation,
    required Widget child,
    double maxOffset = 20.0,
  }) {
    return Transform.translate(
      offset: getSafeTranslation(animation.value, maxOffset),
      child: child,
    );
  }

  // Safe opacity widget
  static Widget buildSafeOpacity({
    required Animation<double> animation,
    required Widget child,
  }) {
    return Opacity(opacity: getSafeOpacity(animation.value), child: child);
  }

  // Safe transform scale
  static Widget buildSafeTransformScale({
    required Animation<double> animation,
    required Widget child,
    double minScale = 0.0,
    double maxScale = 1.0,
  }) {
    final scale = getSafeScale(animation.value).clamp(minScale, maxScale);
    return Transform.scale(scale: scale, child: child);
  }
}

// Safe Animation Mixin
mixin SafeAnimationMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider {
  late AnimationController _safeController;

  AnimationController get safeController => _safeController;

  void initSafeController({
    Duration duration = const Duration(milliseconds: 300),
    double lowerBound = 0.0,
    double upperBound = 1.0,
  }) {
    _safeController = AnimationUtils.createSafeController(
      vsync: this,
      duration: duration,
      lowerBound: lowerBound,
      upperBound: upperBound,
    );
  }

  @override
  void dispose() {
    _safeController.dispose();
    super.dispose();
  }

  // Safe forward animation
  Future<void> safeForward() async {
    try {
      await _safeController.forward();
    } catch (e) {
      print('Animation error: $e');
      _safeController.reset();
    }
  }

  // Safe reverse animation
  Future<void> safeReverse() async {
    try {
      await _safeController.reverse();
    } catch (e) {
      print('Animation error: $e');
      _safeController.reset();
    }
  }

  // Safe reset animation
  void safeReset() {
    try {
      _safeController.reset();
    } catch (e) {
      print('Animation reset error: $e');
    }
  }
}
