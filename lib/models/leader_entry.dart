// lib/models/leader_entry.dart
// Leaderboard data layer: model for simplified leaderboard entry

import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderEntry {
  final String uid;
  final String username; // fallback to displayName or email prefix if missing
  final String? avatarUrl;
  final int rankValue; // metric value (level / longestStreak / totalQuizzesCompleted)
  final int? secondary; // e.g., currentStreak for streak metric
  final int index; // 1..10; set in service mapping stage

  const LeaderEntry({
    required this.uid,
    required this.username,
    required this.rankValue,
    this.secondary,
    this.avatarUrl,
    this.index = 0,
  });

  // Factory with defensive parsing
  // metric: 'level' | 'streak' | 'quiz'
  static LeaderEntry fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String metric,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final statsRaw = data['stats'];
    final stats = statsRaw is Map<String, dynamic> ? statsRaw : <String, dynamic>{};

    String _stringOrEmpty(dynamic v) => v is String ? v : '';
    int _intOrDefault(dynamic v, int def) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return def;
    }

    // Username fallback chain: stats.username -> displayName -> email prefix -> 'User'
    String username = _stringOrEmpty(stats['username']).trim();
    if (username.isEmpty) {
      username = _stringOrEmpty(data['displayName']).trim();
    }
    if (username.isEmpty) {
      final email = _stringOrEmpty(data['email']).trim();
      if (email.contains('@')) {
        username = email.split('@').first;
      }
    }
    if (username.isEmpty) {
      username = 'User';
    }

    final avatarCandidate = stats['photoURL'];
    final avatarUrl = (avatarCandidate is String && avatarCandidate.trim().isNotEmpty)
        ? avatarCandidate
        : null;

    // Defaults for missing stats
    final level = _intOrDefault(stats['level'], 1);
    final longestStreak = _intOrDefault(stats['longestStreak'], 0);
    final currentStreak = _intOrDefault(stats['currentStreak'], 0);
    final totalQuizzes = _intOrDefault(stats['totalQuizzesCompleted'], 0);

    int rankValue;
    int? secondary;
    switch (metric) {
      case 'level':
        rankValue = level;
        secondary = null;
        break;
      case 'streak':
        rankValue = longestStreak;
        secondary = currentStreak;
        break;
      case 'quiz':
        rankValue = totalQuizzes;
        secondary = null;
        break;
      default:
        // Unknown metric, treat as 0
        rankValue = 0;
        secondary = null;
    }

    return LeaderEntry(
      uid: doc.id,
      username: username,
      avatarUrl: avatarUrl,
      rankValue: rankValue,
      secondary: secondary,
      index: 0, // will be set in service mapping
    );
  }

  LeaderEntry withIndex(int index) => LeaderEntry(
        uid: uid,
        username: username,
        avatarUrl: avatarUrl,
        rankValue: rankValue,
        secondary: secondary,
        index: index,
      );

  @override
  String toString() {
    return 'LeaderEntry(uid: $uid, username: $username, rankValue: $rankValue, secondary: $secondary, index: $index)';
  }
}