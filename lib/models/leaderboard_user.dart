// lib/models/leaderboard_user.dart
// Leaderboard User Model

import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardUser {
  final String userId;
  final String displayName;
  final String? photoURL;
  final int currentLevel;
  final int highestLevel; // 🏆 Tüm zamanlar en yüksek level
  final int totalXp;
  final int weeklyXp;
  final int currentStreak;
  final int longestStreak;
  final int quizzesCompleted;
  final int wordsLearned;
  final int rank;
  final int? previousRank;
  final DateTime lastUpdated;
  final bool isCurrentUser;

  LeaderboardUser({
    required this.userId,
    required this.displayName,
    this.photoURL,
    required this.currentLevel,
    required this.highestLevel,
    required this.totalXp,
    required this.weeklyXp,
    required this.currentStreak,
    required this.longestStreak,
    required this.quizzesCompleted,
    required this.wordsLearned,
    required this.rank,
    this.previousRank,
    required this.lastUpdated,
    this.isCurrentUser = false,
  });

  /// Get rank change (positive = moved up, negative = moved down)
  int? get rankChange {
    if (previousRank == null) return null;
    return previousRank! - rank; // Positive means improvement
  }

  /// Get metric value based on leaderboard type
  int getMetricValue(String leaderboardType) {
    switch (leaderboardType) {
      case 'weekly_xp':
        return weeklyXp;
      case 'all_time_level':
        return highestLevel;
      case 'current_streak':
        return currentStreak;
      case 'quiz_master':
        return quizzesCompleted;
      default:
        return totalXp;
    }
  }

  /// Factory from Firestore document
  factory LeaderboardUser.fromFirestore(
    DocumentSnapshot doc,
    String currentUserId,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Type guards for numeric fields to prevent FieldValue type errors
    final rawCurrentLevel = data['currentLevel'];
    final currentLevel = rawCurrentLevel is int ? rawCurrentLevel : 1;
    
    final rawHighestLevel = data['highestLevel'];
    final highestLevel = rawHighestLevel is int ? rawHighestLevel : currentLevel;
    
    final rawCurrentStreak = data['currentStreak'];
    final currentStreak = rawCurrentStreak is int ? rawCurrentStreak : 0;
    
    final rawLongestStreak = data['longestStreak'];
    final longestStreak = rawLongestStreak is int ? rawLongestStreak : 0;
    
    final rawTotalXp = data['totalXp'];
    final totalXp = rawTotalXp is int ? rawTotalXp : 0;
    
    final rawWeeklyXp = data['weeklyXp'];
    final weeklyXp = rawWeeklyXp is int ? rawWeeklyXp : 0;
    
    final rawQuizzesCompleted = data['quizzesCompleted'];
    final quizzesCompleted = rawQuizzesCompleted is int ? rawQuizzesCompleted : 0;
    
    final rawWordsLearned = data['wordsLearned'];
    final wordsLearned = rawWordsLearned is int ? rawWordsLearned : 0;
    
    final rawRank = data['rank'];
    final rank = rawRank is int ? rawRank : 0;
    
    final rawPreviousRank = data['previousRank'];
    final previousRank = rawPreviousRank is int ? rawPreviousRank : null;
    
    return LeaderboardUser(
      userId: doc.id,
      displayName: data['displayName'] ?? 'Anonymous',
      photoURL: data['photoURL'],
      currentLevel: currentLevel,
      highestLevel: highestLevel > currentLevel ? highestLevel : currentLevel,
      totalXp: totalXp,
      weeklyXp: weeklyXp,
      currentStreak: currentStreak,
      longestStreak: longestStreak > currentStreak ? longestStreak : currentStreak,
      quizzesCompleted: quizzesCompleted,
      wordsLearned: wordsLearned,
      rank: rank,
      previousRank: previousRank,
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCurrentUser: doc.id == currentUserId,
    );
  }

  /// To Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'photoURL': photoURL,
      'currentLevel': currentLevel,
      'highestLevel': highestLevel,
      'totalXp': totalXp,
      'weeklyXp': weeklyXp,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'quizzesCompleted': quizzesCompleted,
      'wordsLearned': wordsLearned,
      'rank': rank,
      'previousRank': previousRank,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  LeaderboardUser copyWith({
    String? userId,
    String? displayName,
    String? photoURL,
    int? currentLevel,
    int? highestLevel,
    int? totalXp,
    int? weeklyXp,
    int? currentStreak,
    int? longestStreak,
    int? quizzesCompleted,
    int? wordsLearned,
    int? rank,
    int? previousRank,
    DateTime? lastUpdated,
    bool? isCurrentUser,
  }) {
    return LeaderboardUser(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      currentLevel: currentLevel ?? this.currentLevel,
      highestLevel: highestLevel ?? this.highestLevel,
      totalXp: totalXp ?? this.totalXp,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      quizzesCompleted: quizzesCompleted ?? this.quizzesCompleted,
      wordsLearned: wordsLearned ?? this.wordsLearned,
      rank: rank ?? this.rank,
      previousRank: previousRank ?? this.previousRank,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}

/// Leaderboard Type Definition
class LeaderboardType {
  final String id;
  final String name;
  final String icon;
  final String description;
  final String metric;
  final String resetPeriod; // 'daily', 'weekly', 'never'
  final String unit;

  const LeaderboardType({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.metric,
    required this.resetPeriod,
    required this.unit,
  });

  static const weeklyXp = LeaderboardType(
    id: 'weekly_xp',
    name: 'Haftalık XP Liderleri',
    icon: '⚡',
    description: 'Bu hafta en çok XP kazananlar',
    metric: 'weeklyXp',
    resetPeriod: 'weekly',
    unit: 'XP',
  );

  static const allTimeLevel = LeaderboardType(
    id: 'all_time_level',
    name: 'Tüm Zamanların Liderleri',
    icon: '🏆',
    description: 'En yüksek levele sahip kullanıcılar',
    metric: 'highestLevel',
    resetPeriod: 'never',
    unit: 'Level',
  );

  static const currentStreak = LeaderboardType(
    id: 'current_streak',
    name: 'Günlük Seri Liderleri',
    icon: '🔥',
    description: 'En uzun günlük giriş serisi',
    metric: 'currentStreak',
    resetPeriod: 'daily',
    unit: 'Gün',
  );

  static const quizMaster = LeaderboardType(
    id: 'quiz_master',
    name: 'Quiz Şampiyonları',
    icon: '🧠',
    description: 'En çok quiz tamamlayanlar',
    metric: 'quizzesCompleted',
    resetPeriod: 'weekly',
    unit: 'Quiz',
  );

  static const List<LeaderboardType> all = [
    weeklyXp,
    allTimeLevel,
    currentStreak,
    quizMaster,
  ];

  static LeaderboardType fromId(String id) {
    return all.firstWhere((type) => type.id == id, orElse: () => weeklyXp);
  }
}
