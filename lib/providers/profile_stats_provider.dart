import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/aggregated_profile_stats.dart';
import '../services/level_service.dart';
import '../services/streak_service.dart';
import '../utils/logger.dart';
import '../utils/streak_migration_helper.dart';

class ProfileStatsProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  AggregatedProfileStats _stats = AggregatedProfileStats.loading();
  StreamSubscription<DocumentSnapshot>? _leaderboardSubscription;
  StreamSubscription<DocumentSnapshot>? _summarySubscription;
  StreamSubscription<QuerySnapshot>? _learnedWordsSubscription;
  
  Map<String, dynamic>? _leaderboardData;
  Map<String, dynamic>? _summaryData;
  int? _liveLearnedWordsCount;
  
  String? _currentUserId;
  bool _disposed = false;
  bool _initialized = false;
  String? _error;
  
  // Level-up detection
  int _lastAnnouncedLevel = 1;
  LevelData? _currentLevelData;

  AggregatedProfileStats get stats => _stats;
  bool get isLoading => _stats.isLoading;
  String? get error => _error;
  LevelData? get currentLevelData => _currentLevelData;
  
  /// Single source of truth for learned count
  int get learnedCount => _stats.learnedWordsCount;
  
  /// Debug source for learned count ("subcol" | "fallback")
  String? get learnedDebugSource => _liveLearnedWordsCount != null ? "subcol" : "fallback";

  /// Initialize streams for the given user
  Future<void> initializeForUser(String userId) async {
    if (_disposed) return;
    
    // Prevent duplicate initializations
    if (_initialized && _currentUserId == userId && _leaderboardSubscription != null) {
      Logger.i('[PROFILE] Already initialized for user: $userId', 'ProfileStatsProvider');
      return;
    }

    try {
      Logger.i('[PROFILE] Provider initializing for user: $userId', 'ProfileStatsProvider');
      
      // Clean up previous subscriptions
      await _cancelSubscriptions();
      
      _currentUserId = userId;
      _initialized = true;
      _error = null;
      _stats = AggregatedProfileStats.loading();
      _safeNotifyListeners();

      // Run migration helper to ensure streak data exists
      await StreakMigrationHelper.migrateUserStreakData();

      Logger.i('[PROFILE] Initializing triple streams for user: $userId', 'ProfileStatsProvider');

      // Start leaderboard_stats stream
      _leaderboardSubscription = _firestore
          .collection('leaderboard_stats')
          .doc(userId)
          .snapshots()
          .listen(
            _onLeaderboardUpdate,
            onError: (error) {
              Logger.e('[PROFILE] Leaderboard stream error', error, null, 'ProfileStatsProvider');
              if (!_disposed) {
                _error = 'Leaderboard verisi yüklenemedi: ${error.toString()}';
                _safeNotifyListeners();
              }
            },
          );

      // Check if disposed after async operation
      if (_disposed) return;

      // Start users/stats/summary stream
      _summarySubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('summary')
          .snapshots()
          .listen(
            _onSummaryUpdate,
            onError: (error) {
              Logger.e('[PROFILE] Summary stream error', error, null, 'ProfileStatsProvider');
              if (!_disposed) {
                _error = 'Profil verisi yüklenemedi: ${error.toString()}';
                _safeNotifyListeners();
              }
            },
          );

      // Check if disposed after async operation
      if (_disposed) return;

      // Start learned_words subcollection stream (canonical source)
      _learnedWordsSubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('learned_words')
          .snapshots()
          .listen(
            _onLearnedWordsUpdate,
            onError: (error) {
              Logger.e('[PROFILE] Learned words stream error', error, null, 'ProfileStatsProvider');
              // Don't set error for learned words stream - fallback to cached count
              if (!_disposed) {
                _liveLearnedWordsCount = null; // Clear live count, will fallback to cached
                _combineAndUpdate();
              }
            },
          );

      // Perform reconciliation after streams are set up
      await _performReconciliation(userId);
      
      // Initialize streak system for the user
      await ensureStreakDefaults();
      await checkStreakReset();
    } catch (e) {
      Logger.e('[PROFILE] Initialization failed', e, null, 'ProfileStatsProvider');
      if (!_disposed) {
        _error = 'Profil başlatılamadı: ${e.toString()}';
        _safeNotifyListeners();
      }
    }
  }

  void _onLeaderboardUpdate(DocumentSnapshot snapshot) {
    if (_disposed) return;
    
    _leaderboardData = snapshot.exists ? snapshot.data() as Map<String, dynamic>? : null;
    _combineAndUpdate();
  }

  void _onLearnedWordsUpdate(QuerySnapshot snapshot) {
    if (_disposed) return;
    
    final previousCount = _liveLearnedWordsCount;
    _liveLearnedWordsCount = snapshot.docs.length;
    
    // Log telemetry for learned words count changes
    if (previousCount != null && previousCount != _liveLearnedWordsCount) {
      Logger.i('[TELEMETRY] learned_words_count_changed: ${previousCount} -> ${_liveLearnedWordsCount} (uid=${_currentUserId})', 'ProfileStatsProvider');
    }
    
    Logger.i('[PROFILE] Live learned words count updated: ${_liveLearnedWordsCount}', 'ProfileStatsProvider');
    _combineAndUpdate();
  }

  /// Perform reconciliation between live subcollection count and cached field
  Future<void> _performReconciliation(String userId) async {
    if (_disposed) return;

    try {
      // Get actual count from subcollection (single snapshot)
      final learnedWordsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('learned_words')
          .get();
      
      final actualCount = learnedWordsSnapshot.docs.length;

      // Get cached count from user document
      final userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      final userData = userDoc.data();
      final cachedCount = userData?['learnedWordsCount'] as int?;

      // Check if reconciliation is needed
      if (cachedCount != actualCount || cachedCount == null || cachedCount < 0) {
        Logger.i('[RECONCILE] learnedWordsCount: cached=$cachedCount → actual=$actualCount (uid=$userId)', 'ProfileStatsProvider');
        
        // Update cached count to match actual count
        await _firestore
            .collection('users')
            .doc(userId)
            .update({
          'learnedWordsCount': actualCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Also update leaderboard stats to keep them in sync
        await _firestore
            .collection('leaderboard_stats')
            .doc(userId)
            .update({
          'learnedWordsCount': actualCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        Logger.i('[RECONCILE] learnedWordsCount: cached=$cachedCount matches actual=$actualCount (uid=$userId)', 'ProfileStatsProvider');
      }
    } catch (e) {
      Logger.e('[PROFILE] Reconciliation failed', e, null, 'ProfileStatsProvider');
      // Don't fail initialization due to reconciliation errors
    }
  }

  void _onSummaryUpdate(DocumentSnapshot snapshot) {
    if (_disposed) return;
    
    _summaryData = snapshot.exists ? snapshot.data() as Map<String, dynamic>? : null;
    _combineAndUpdate();
  }

  void _combineAndUpdate() {
    if (_disposed) return;

    final newStats = AggregatedProfileStats.fromSources(
      leaderboardData: _leaderboardData,
      summaryData: _summaryData,
      liveLearnedWordsCount: _liveLearnedWordsCount, // Pass live count as priority
    );

    // Compute level data from totalXp
    final totalXp = newStats.totalXp;
    final newLevelData = LevelService.computeLevelData(totalXp);
    
    Logger.i(
      '[LEVEL] compute totalXp=$totalXp -> level=${newLevelData.level}, into=${newLevelData.xpIntoLevel}/${newLevelData.xpNeeded}',
      'ProfileStatsProvider'
    );

    // Check for level-up
    if (newLevelData.level > _lastAnnouncedLevel && !_disposed) {
      Logger.i('[LEVEL] banner Level ${newLevelData.level} shown', 'ProfileStatsProvider');
      _lastAnnouncedLevel = newLevelData.level;
      
      // Mirror level to users/{uid}.level
      _mirrorLevelToFirestore(newLevelData.level);
      
      // Trigger level-up banner (will be handled by UI)
      _triggerLevelUpBanner(newLevelData.level);
    }

    // Log the combined stats
    Logger.i(
      '[PROFILE] combine <- xp=${newStats.totalXp}, quizzes=${newStats.totalQuizzesCompleted}, learned=${newStats.learnedWordsCount}',
      'ProfileStatsProvider'
    );

    // Add telemetry for learned count binding
    final debugSource = _liveLearnedWordsCount != null ? "subcol" : "fallback";
    Logger.i(
      '[PROFILE] learned bind -> ${newStats.learnedWordsCount} (src=${debugSource})',
      'ProfileStatsProvider'
    );
    
    // Add HOME-specific telemetry for dashboard updates
    Logger.i(
      '[HOME] learnedCount updated: ${newStats.learnedWordsCount} (src=${debugSource})',
      'ProfileStatsProvider'
    );

    _stats = newStats;
    _currentLevelData = newLevelData;
    _safeNotifyListeners();
  }

  /// Mirror level to users/{uid}.level when it changes
  Future<void> _mirrorLevelToFirestore(int level) async {
    if (_disposed || _currentUserId == null) return;

    try {
      // Mirror to users collection
      await LevelService.mirrorLevelToUser(_currentUserId!, level);
      Logger.i('[LEVEL] mirror write: users/${_currentUserId}.level=$level', 'ProfileStatsProvider');
      
      // Also mirror to leaderboard_stats collection
      await _firestore
          .collection('leaderboard_stats')
          .doc(_currentUserId!)
          .update({
        'level': level,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      Logger.i('[LEVEL] mirror write: leaderboard_stats/${_currentUserId}.level=$level', 'ProfileStatsProvider');
    } catch (e) {
      Logger.e('[LEVEL] Failed to mirror level to Firestore', e, null, 'ProfileStatsProvider');
    }
  }

  /// Trigger level-up banner (to be handled by UI layer)
  void _triggerLevelUpBanner(int level) {
    // This will be handled by the UI layer listening to this provider
    // The UI can check if currentLevelData.level > previous level and show banner
  }

  /// Safe notifyListeners that checks disposal state
  void _safeNotifyListeners() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Cancel all active subscriptions safely
  Future<void> _cancelSubscriptions() async {
    await _leaderboardSubscription?.cancel();
    await _summarySubscription?.cancel();
    await _learnedWordsSubscription?.cancel();
    _leaderboardSubscription = null;
    _summarySubscription = null;
    _learnedWordsSubscription = null;
  }

  /// Manually refresh both streams (for pull-to-refresh)
  Future<void> refresh() async {
    if (_disposed || _currentUserId == null) return;

    Logger.i('[PROFILE] Manual refresh requested', 'ProfileStatsProvider');
    
    try {
      // Force refresh by re-reading documents
      final leaderboardFuture = _firestore
          .collection('leaderboard_stats')
          .doc(_currentUserId!)
          .get(const GetOptions(source: Source.server));
          
      final summaryFuture = _firestore
          .collection('users')
          .doc(_currentUserId!)
          .collection('stats')
          .doc('summary')
          .get(const GetOptions(source: Source.server));

      final results = await Future.wait([leaderboardFuture, summaryFuture]);
      
      // Check if disposed after async operation
      if (_disposed) return;
      
      _leaderboardData = results[0].exists ? results[0].data() : null;
      _summaryData = results[1].exists ? results[1].data() : null;
      
      _error = null; // Clear any previous errors
      _combineAndUpdate();
    } catch (e) {
      Logger.e('[PROFILE] Refresh failed', e, null, 'ProfileStatsProvider');
      if (!_disposed) {
        _error = 'Yenileme başarısız: ${e.toString()}';
        _safeNotifyListeners();
      }
    }
  }

  /// Retry initialization after error
  Future<void> retry() async {
    if (_disposed || _currentUserId == null) return;
    
    Logger.i('[PROFILE] Retrying initialization', 'ProfileStatsProvider');
    _error = null;
    await initializeForUser(_currentUserId!);
  }

  /// Dispose streams and clean up
  @override
  Future<void> dispose() async {
    Logger.i('[PROFILE] Provider disposed cleanly', 'ProfileStatsProvider');
    
    _disposed = true;
    _initialized = false;
    
    await _cancelSubscriptions();
    
    _leaderboardData = null;
    _summaryData = null;
    _liveLearnedWordsCount = null;
    _currentUserId = null;
    _error = null;
    
    super.dispose();
  }

  /// Initialize from current Firebase Auth user
  Future<void> initializeFromAuth() async {
    if (_disposed) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await initializeForUser(user.uid);
    }
  }

  // ========== STREAK MANAGEMENT ==========
  
  /// Ensure initial streak defaults for new users
  Future<void> ensureStreakDefaults() async {
    if (_disposed || _currentUserId == null) return;
    
    try {
      await StreakService.ensureInitialDefaults(_currentUserId!);
      Logger.i('[STREAK] Initial defaults ensured for user ${_currentUserId}', 'ProfileStatsProvider');
    } catch (e) {
      Logger.e('[STREAK] Failed to ensure defaults', e, null, 'ProfileStatsProvider');
    }
  }
  
  /// Increment streak if it's a new day and notify listeners
  /// Returns true if streak was incremented
  Future<bool> incrementStreakIfNewDay() async {
    if (_disposed || _currentUserId == null) return false;
    
    try {
      final wasIncremented = await StreakService.incrementIfNewDay(_currentUserId!);
      
      if (wasIncremented) {
        // Refresh data to get updated streak values
        await refresh();
        Logger.i('[STREAK] Streak incremented and UI refreshed for user ${_currentUserId}', 'ProfileStatsProvider');
      }
      
      return wasIncremented;
    } catch (e) {
      Logger.e('[STREAK] Failed to increment streak', e, null, 'ProfileStatsProvider');
      return false;
    }
  }
  
  /// Migrate existing user to proper streak defaults
  Future<void> migrateUserStreak() async {
    if (_disposed || _currentUserId == null) return;
    
    try {
      await StreakService.migrateExistingUser(_currentUserId!);
      // Refresh data to reflect migration changes
      await refresh();
      Logger.i('[STREAK] User migration completed for ${_currentUserId}', 'ProfileStatsProvider');
    } catch (e) {
      Logger.e('[STREAK] Migration failed', e, null, 'ProfileStatsProvider');
    }
  }
  
  /// Check and reset streak if user missed days
  Future<void> checkStreakReset() async {
    if (_disposed || _currentUserId == null) return;
    
    try {
      await StreakService.checkAndResetStreakIfNeeded(_currentUserId!);
      // Refresh data to reflect any reset
      await refresh();
      Logger.i('[STREAK] Streak reset check completed for ${_currentUserId}', 'ProfileStatsProvider');
    } catch (e) {
      Logger.e('[STREAK] Streak reset check failed', e, null, 'ProfileStatsProvider');
    }
  }
  
  /// Get current streak value from stats
  int get currentStreak {
    final raw = _stats.currentStreak;
    return raw > 0 ? raw : 1;
  }
  
  /// Get longest streak value from stats
  int get longestStreak => _stats?.longestStreak ?? 0;
}