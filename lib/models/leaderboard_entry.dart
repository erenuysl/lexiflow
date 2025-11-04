// lib/models/leaderboard_entry.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String uid;
  final String username;
  final String? photoURL;
  final int level;
  final int totalXp;
  final int weeklyXp;

  LeaderboardEntry({
    required this.uid,
    required this.username,
    required this.level,
    required this.totalXp,
    required this.weeklyXp,
    this.photoURL,
  });

  static LeaderboardEntry fromUserDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final stats = (data['stats'] as Map<String, dynamic>?) ?? {};

    final usernameRaw = stats['username'] ?? data['displayName'];
    final username = (usernameRaw is String && usernameRaw.trim().isNotEmpty)
        ? usernameRaw
        : 'Unknown';

    final levelRaw = stats['level'];
    final level = levelRaw is int ? levelRaw : 0;

    final totalXpRaw = stats['totalXp'];
    final totalXp = totalXpRaw is int ? totalXpRaw : 0;

    final weeklyXpRaw = stats['weeklyXp'];
    final weeklyXp = weeklyXpRaw is int ? weeklyXpRaw : 0; // fallback to 0

    final photo = stats['photoURL'] ?? data['avatar'] ?? data['photoURL'];
    final photoURL = (photo is String && photo.trim().isNotEmpty) ? photo : null;

    return LeaderboardEntry(
      uid: doc.id,
      username: username,
      level: level,
      totalXp: totalXp,
      weeklyXp: weeklyXp,
      photoURL: photoURL,
    );
  }
}