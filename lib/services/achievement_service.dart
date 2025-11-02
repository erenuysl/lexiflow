import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../utils/logger.dart';
import 'session_service.dart';
import 'achievement_popup_service.dart';

class AchievementService extends ChangeNotifier {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SessionService _sessionService = SessionService();
  final AchievementPopupService _popupService = AchievementPopupService();
  
  List<Achievement> _achievements = [];
  StreamSubscription<DocumentSnapshot>? _userStatsListener;
  bool _isInitialized = false;
  
  // Cache for user stats to avoid excessive reads
  Map<String, dynamic>? _cachedUserStats;
  DateTime? _lastStatsUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  List<Achievement> get achievements => List.unmodifiable(_achievements);
  bool get isInitialized => _isInitialized;

  /// Initialize achievement service and start listening to user stats
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      Logger.i('Initializing AchievementService...', 'AchievementService');
      
      // Load initial achievements
      await _loadAchievements();
      
      // Set up real-time listener for user stats
      _setupUserStatsListener();
      
      _isInitialized = true;
      Logger.i('AchievementService initialized successfully', 'AchievementService');
      notifyListeners();
    } catch (e) {
      Logger.e('Failed to initialize AchievementService', e, null, 'AchievementService');
    }
  }

  /// Load achievements from Firestore or create default ones
  Future<void> _loadAchievements() async {
    final userId = _sessionService.currentUser?.uid;
    if (userId == null) {
      Logger.w('Cannot load achievements: user not authenticated', 'AchievementService');
      return;
    }

    try {
      // Try to load saved achievements from Firestore
      final achievementDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc('user_achievements')
          .get();

      Map<String, int> progressMap = {};
      Set<String> unlockedSet = {};

      if (achievementDoc.exists && achievementDoc.data() != null) {
        final data = achievementDoc.data()!;
        
        // Extract progress and unlocked status
        final progress = data['progress'] as Map<String, dynamic>? ?? {};
        final unlocked = data['unlocked'] as List<dynamic>? ?? [];
        
        progressMap = progress.map((key, value) => MapEntry(key, value as int? ?? 0));
        unlockedSet = unlocked.cast<String>().toSet();
        
        Logger.i('Loaded achievements from Firestore: ${progressMap.length} progress entries, ${unlockedSet.length} unlocked', 'AchievementService');
      } else {
        Logger.i('No saved achievements found, creating defaults', 'AchievementService');
      }

      // Create achievements with current progress
      _achievements = AchievementDefinitions.getAllAchievements(
        progressMap: progressMap,
        unlockedSet: unlockedSet,
      );

      // Update progress based on current user stats
      await _updateAchievementProgress();
      
    } catch (e) {
      Logger.e('Failed to load achievements', e, null, 'AchievementService');
      // Create default achievements on error
      _achievements = AchievementDefinitions.getAllAchievements();
    }
  }

  /// Set up real-time listener for user stats changes
  void _setupUserStatsListener() {
    final userId = _sessionService.currentUser?.uid;
    if (userId == null) return;

    _userStatsListener?.cancel();
    _userStatsListener = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          _cachedUserStats = snapshot.data()!;
          _lastStatsUpdate = DateTime.now();
          
          // Update achievement progress when stats change
          _updateAchievementProgress();
          
          Logger.d('User stats updated, recalculating achievements', 'AchievementService');
        }
      },
      onError: (error) {
        Logger.e('User stats listener error', error, null, 'AchievementService');
      },
    );
  }

  /// Update achievement progress based on current user stats
  Future<void> _updateAchievementProgress() async {
    if (_cachedUserStats == null) {
      await _refreshUserStats();
    }

    if (_cachedUserStats == null) return;

    final stats = _cachedUserStats!;
    final learnedWordsCount = stats['learnedWordsCount'] as int? ?? 0;
    final currentStreak = stats['currentStreak'] as int? ?? 0;
    final totalQuizzesCompleted = stats['totalQuizzesCompleted'] as int? ?? 0;

    List<Achievement> updatedAchievements = [];
    List<Achievement> newlyUnlocked = [];

    for (final achievement in _achievements) {
      int newProgress = 0;
      
      // Calculate progress based on achievement type
      switch (achievement.id) {
        case 'learned_words_100':
          newProgress = learnedWordsCount;
          break;
        case 'streak_10':
          newProgress = currentStreak;
          break;
        case 'quizzes_25':
          newProgress = totalQuizzesCompleted;
          break;
      }

      // Check if achievement should be unlocked
      final shouldBeUnlocked = newProgress >= achievement.target;
      final wasAlreadyUnlocked = achievement.unlocked;

      final updatedAchievement = achievement.copyWith(
        progress: newProgress,
        unlocked: shouldBeUnlocked,
      );

      updatedAchievements.add(updatedAchievement);

      // Track newly unlocked achievements
      if (shouldBeUnlocked && !wasAlreadyUnlocked) {
        newlyUnlocked.add(updatedAchievement);
      }
    }

    _achievements = updatedAchievements;

    // Award XP for newly unlocked achievements
    for (final achievement in newlyUnlocked) {
      await _awardAchievementXp(achievement);
    }

    // Save updated achievements to Firestore
    await _saveAchievements();

    notifyListeners();
  }

  /// Award XP when an achievement is unlocked
  Future<void> _awardAchievementXp(Achievement achievement) async {
    try {
      // Use SessionService to add XP with achievement type
      await _sessionService.addQuizXp('achievement', achievement.xpReward ~/ 10);
      
      Logger.i('🏆 Achievement unlocked: ${achievement.title} (+${achievement.xpReward} XP)', 'AchievementService');
      
      // You could also show a notification here
      // NotificationService.showAchievementUnlocked(achievement);
      
    } catch (e) {
      Logger.e('Failed to award achievement XP', e, null, 'AchievementService');
    }
  }

  /// Save achievements to Firestore
  Future<void> _saveAchievements() async {
    final userId = _sessionService.currentUser?.uid;
    if (userId == null) return;

    try {
      final progressMap = <String, int>{};
      final unlockedList = <String>[];

      for (final achievement in _achievements) {
        progressMap[achievement.id] = achievement.progress;
        if (achievement.unlocked) {
          unlockedList.add(achievement.id);
        }
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc('user_achievements')
          .set({
        'progress': progressMap,
        'unlocked': unlockedList,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Logger.d('Achievements saved to Firestore', 'AchievementService');
    } catch (e) {
      Logger.e('Failed to save achievements', e, null, 'AchievementService');
    }
  }

  /// Refresh user stats from Firestore
  Future<void> _refreshUserStats() async {
    final userId = _sessionService.currentUser?.uid;
    if (userId == null) return;

    // Check cache validity
    if (_cachedUserStats != null && _lastStatsUpdate != null) {
      final cacheAge = DateTime.now().difference(_lastStatsUpdate!);
      if (cacheAge < _cacheValidDuration) {
        return; // Cache is still valid
      }
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        _cachedUserStats = userDoc.data()!;
        _lastStatsUpdate = DateTime.now();
        Logger.d('User stats refreshed from Firestore', 'AchievementService');
      }
    } catch (e) {
      Logger.e('Failed to refresh user stats', e, null, 'AchievementService');
    }
  }

  /// Get achievement by ID
  Achievement? getAchievementById(String id) {
    try {
      return _achievements.firstWhere((achievement) => achievement.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get unlocked achievements count
  int get unlockedCount => _achievements.where((a) => a.unlocked).length;

  /// Get total achievements count
  int get totalCount => _achievements.length;

  /// Get completion percentage (0.0 to 1.0)
  double get completionPercentage {
    if (_achievements.isEmpty) return 0.0;
    return unlockedCount / totalCount;
  }

  /// Force refresh achievements (useful for testing or manual refresh)
  Future<void> refreshAchievements() async {
    await _refreshUserStats();
    await _updateAchievementProgress();
  }

  /// Dispose resources
  @override
  void dispose() {
    _userStatsListener?.cancel();
    super.dispose();
  }

  /// Show achievement unlock popup
  /// This method should be called from UI components when they want to show popups
  Future<void> showAchievementPopup(BuildContext context, Achievement achievement) async {
    await _popupService.showAchievementUnlocked(context, achievement);
  }

  /// Reset achievements (for testing purposes)
  Future<void> resetAchievements() async {
    final userId = _sessionService.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc('user_achievements')
          .delete();

      _achievements = AchievementDefinitions.getAllAchievements();
      notifyListeners();
      
      Logger.i('Achievements reset successfully', 'AchievementService');
    } catch (e) {
      Logger.e('Failed to reset achievements', e, null, 'AchievementService');
    }
  }

  /// Test method to manually trigger achievement popup (for testing purposes)
  Future<void> testAchievementPopup(BuildContext context) async {
    // Create a test achievement
    final testAchievement = Achievement(
      id: 'test_achievement',
      title: 'Test Başarımı',
      description: 'Bu bir test başarımıdır',
      icon: Icons.star,
      unlocked: true,
      progress: 1,
      target: 1,
      xpReward: 100,
    );

    Logger.i('🧪 Triggering test achievement popup', 'AchievementService');
    await _popupService.showAchievementUnlocked(context, testAchievement);
  }
}