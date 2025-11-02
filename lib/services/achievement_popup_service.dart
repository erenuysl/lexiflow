import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../widgets/achievement_unlock_popup.dart';
import '../utils/logger.dart';

class AchievementPopupService {
  static final AchievementPopupService _instance = AchievementPopupService._internal();
  factory AchievementPopupService() => _instance;
  AchievementPopupService._internal();

  // Keep track of currently showing popup to prevent overlaps
  bool _isShowingPopup = false;
  final List<Achievement> _queuedAchievements = [];

  /// Show achievement unlock popup
  /// This method is safe to call multiple times - it will queue achievements if one is already showing
  Future<void> showAchievementUnlocked(
    BuildContext context,
    Achievement achievement,
  ) async {
    try {
      Logger.i('🎉 Showing achievement unlock popup: ${achievement.title}', 'AchievementPopupService');

      // If already showing a popup, queue this achievement
      if (_isShowingPopup) {
        Logger.d('Popup already showing, queuing achievement: ${achievement.title}', 'AchievementPopupService');
        _queuedAchievements.add(achievement);
        return;
      }

      await _displayPopup(context, achievement);
      
      // Process queued achievements
      await _processQueue(context);
      
    } catch (e) {
      Logger.e('Failed to show achievement popup', e, null, 'AchievementPopupService');
    }
  }

  /// Display the actual popup
  Future<void> _displayPopup(BuildContext context, Achievement achievement) async {
    if (!context.mounted) return;

    _isShowingPopup = true;

    try {
      // Show the popup as an overlay
      final overlay = Overlay.of(context);
      late OverlayEntry overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (context) => AchievementUnlockPopup(
          achievement: achievement,
          onComplete: () {
            // Remove the overlay when animation completes
            overlayEntry.remove();
            _isShowingPopup = false;
            Logger.d('Achievement popup completed for: ${achievement.title}', 'AchievementPopupService');
          },
        ),
      );

      // Insert the overlay
      overlay.insert(overlayEntry);

      // Wait for the popup duration (3 seconds total)
      await Future.delayed(const Duration(seconds: 3));

    } catch (e) {
      _isShowingPopup = false;
      Logger.e('Error displaying achievement popup', e, null, 'AchievementPopupService');
    }
  }

  /// Process queued achievements one by one
  Future<void> _processQueue(BuildContext context) async {
    while (_queuedAchievements.isNotEmpty && context.mounted) {
      final nextAchievement = _queuedAchievements.removeAt(0);
      
      // Small delay between popups
      await Future.delayed(const Duration(milliseconds: 500));
      
      await _displayPopup(context, nextAchievement);
    }
  }

  /// Clear the queue (useful for cleanup)
  void clearQueue() {
    _queuedAchievements.clear();
    Logger.d('Achievement popup queue cleared', 'AchievementPopupService');
  }

  /// Check if popup is currently showing
  bool get isShowingPopup => _isShowingPopup;

  /// Get number of queued achievements
  int get queuedCount => _queuedAchievements.length;
}