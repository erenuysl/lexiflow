import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../services/achievement_service.dart';
import '../services/achievement_popup_service.dart';
import '../utils/logger.dart';

/// Service that listens to achievement changes and shows popups automatically
/// This service acts as a bridge between AchievementService and AchievementPopupService
class AchievementListenerService {
  static final AchievementListenerService _instance = AchievementListenerService._internal();
  factory AchievementListenerService() => _instance;
  AchievementListenerService._internal();

  final AchievementService _achievementService = AchievementService();
  final AchievementPopupService _popupService = AchievementPopupService();
  
  BuildContext? _context;
  List<Achievement> _previousAchievements = [];
  bool _isListening = false;

  /// Initialize the listener with a context
  /// This should be called from a widget that has access to BuildContext
  void initialize(BuildContext context) {
    _context = context;
    _previousAchievements = List.from(_achievementService.achievements);
    
    if (!_isListening) {
      _startListening();
    }
    
    Logger.i('Achievement listener initialized', 'AchievementListenerService');
  }

  /// Start listening to achievement changes
  void _startListening() {
    _isListening = true;
    
    _achievementService.addListener(_onAchievementsChanged);
    Logger.d('Started listening to achievement changes', 'AchievementListenerService');
  }

  /// Handle achievement changes and show popups for newly unlocked ones
  void _onAchievementsChanged() {
    if (_context == null || !_context!.mounted) {
      Logger.w('Context not available for showing achievement popup', 'AchievementListenerService');
      return;
    }

    final currentAchievements = _achievementService.achievements;
    
    // Find newly unlocked achievements
    final newlyUnlocked = <Achievement>[];
    
    for (int i = 0; i < currentAchievements.length; i++) {
      final current = currentAchievements[i];
      
      // Check if we have a previous state for this achievement
      if (i < _previousAchievements.length) {
        final previous = _previousAchievements[i];
        
        // If achievement was not unlocked before but is now unlocked
        if (!previous.unlocked && current.unlocked) {
          newlyUnlocked.add(current);
        }
      }
    }

    // Show popups for newly unlocked achievements
    for (final achievement in newlyUnlocked) {
      Logger.i('🎉 New achievement unlocked, showing popup: ${achievement.title}', 'AchievementListenerService');
      _popupService.showAchievementUnlocked(_context!, achievement);
    }

    // Update previous achievements state
    _previousAchievements = List.from(currentAchievements);
  }

  /// Update context (useful when navigating between screens)
  void updateContext(BuildContext context) {
    _context = context;
  }

  /// Stop listening (cleanup)
  void dispose() {
    if (_isListening) {
      _achievementService.removeListener(_onAchievementsChanged);
      _isListening = false;
    }
    _context = null;
    Logger.d('Achievement listener disposed', 'AchievementListenerService');
  }

  /// Check if listener is active
  bool get isListening => _isListening;
}