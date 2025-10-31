import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified profile stats combining canonical sources:
/// - XP & Quizzes from leaderboard_stats/{uid}
/// - Learned words from users/{uid}/stats/summary
import '../services/level_service.dart';

class AggregatedProfileStats {
  final int totalXp;
  final int totalQuizzesCompleted;
  final int learnedWordsCount;
  final int level; // standardized level field
  final int currentStreak;
  final int longestStreak;
  
  // Weekly stats (optional)
  final int? weeklyXp;
  final int? weeklyQuizzes;
  
  // Metadata
  final DateTime lastUpdated;
  final bool isLoading;

  const AggregatedProfileStats({
    required this.totalXp,
    required this.totalQuizzesCompleted,
    required this.learnedWordsCount,
    required this.level, // standardized level field
    required this.currentStreak,
    required this.longestStreak,
    this.weeklyXp,
    this.weeklyQuizzes,
    required this.lastUpdated,
    this.isLoading = false,
  });

  /// Loading state constructor
  AggregatedProfileStats.loading()
      : totalXp = 0,
        totalQuizzesCompleted = 0,
        learnedWordsCount = 0,
        level = 1, // standardized level field
        currentStreak = 0,
        longestStreak = 0,
        weeklyXp = null,
        weeklyQuizzes = null,
        lastUpdated = DateTime.fromMillisecondsSinceEpoch(0),
        isLoading = true;

  /// Create from leaderboard stats and user summary
  factory AggregatedProfileStats.fromSources({
    required Map<String, dynamic>? leaderboardData,
    required Map<String, dynamic>? summaryData,
    int? liveLearnedWordsCount, // Live count from subcollection (priority)
  }) {
    final now = DateTime.now();
    
    // Extract from leaderboard_stats (canonical for XP & quizzes)
    final totalXp = leaderboardData?['totalXp'] ?? 0;
    final totalQuizzesCompleted = leaderboardData?['quizzesCompleted'] ?? 0;
    
    // Calculate level from totalXp using LevelService for consistency
    final calculatedLevel = LevelService.computeLevelData(totalXp is int ? totalXp : 0).level;
    final storedLevel = leaderboardData?['level'] ?? leaderboardData?['currentLevel'] ?? 1;
    // Use calculated level for accuracy, but log if there's a mismatch
    final level = calculatedLevel;
    
    final currentStreak = leaderboardData?['currentStreak'] ?? 0;
    final longestStreak = leaderboardData?['longestStreak'] ?? 0;
    final weeklyXp = leaderboardData?['weeklyXp'];
    final weeklyQuizzes = leaderboardData?['weeklyQuizzes'];
    
    // Prioritize live learned words count from subcollection
    int learnedWordsCount;
    if (liveLearnedWordsCount != null) {
      // Use live count from subcollection (canonical source)
      learnedWordsCount = liveLearnedWordsCount;
    } else {
      // Fallback to cached count from summary data if live stream unavailable
      learnedWordsCount = summaryData?['learnedWordsCount'] ?? 0;
    }
    
    return AggregatedProfileStats(
      totalXp: totalXp is int ? totalXp : 0,
      totalQuizzesCompleted: totalQuizzesCompleted is int ? totalQuizzesCompleted : 0,
      learnedWordsCount: learnedWordsCount is int ? learnedWordsCount : 0,
      level: level is int ? level : 1, // using standardized level field
      currentStreak: currentStreak is int ? currentStreak : 0,
      longestStreak: longestStreak is int ? longestStreak : 0,
      weeklyXp: weeklyXp is int ? weeklyXp : null,
      weeklyQuizzes: weeklyQuizzes is int ? weeklyQuizzes : null,
      lastUpdated: now,
    );
  }

  /// Calculate XP needed for next level using LevelService
  int get xpToNextLevel {
    final levelData = LevelService.computeLevelData(totalXp);
    return levelData.xpNeeded - levelData.xpIntoLevel;
  }
  
  /// Calculate XP progress (0.0 to 1.0) using LevelService
  double get levelProgress {
    final levelData = LevelService.computeLevelData(totalXp);
    return levelData.progressPct;
  }

  /// XP remaining to next level using LevelService
  int get xpToNext {
    final levelData = LevelService.computeLevelData(totalXp);
    return levelData.xpNeeded - levelData.xpIntoLevel;
  }

  @override
  String toString() {
    return 'AggregatedProfileStats(totalXp: $totalXp, quizzes: $totalQuizzesCompleted, '
           'learned: $learnedWordsCount, level: $level, loading: $isLoading)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AggregatedProfileStats &&
        other.totalXp == totalXp &&
        other.totalQuizzesCompleted == totalQuizzesCompleted &&
        other.learnedWordsCount == learnedWordsCount &&
        other.level == level &&
        other.currentStreak == currentStreak &&
        other.longestStreak == longestStreak;
  }

  @override
  int get hashCode {
    return Object.hash(
      totalXp,
      totalQuizzesCompleted,
      learnedWordsCount,
      level,
      currentStreak,
      longestStreak,
    );
  }
}