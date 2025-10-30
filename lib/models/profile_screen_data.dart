import 'package:firebase_auth/firebase_auth.dart';
import '../services/offline_auth_service.dart';

/// 🔥 OPTIMIZED: Data model for ProfileScreen to prevent unnecessary rebuilds
class ProfileScreenData {
  final bool isAuthenticated;
  final int currentLevel;
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final int learnedWordsCount;
  final int totalQuizzesTaken;
  final int favoritesCount;
  final User? currentUser;
  final OfflineGuestUser? offlineUser;

  const ProfileScreenData({
    required this.isAuthenticated,
    required this.currentLevel,
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
    required this.learnedWordsCount,
    required this.totalQuizzesTaken,
    required this.favoritesCount,
    this.currentUser,
    this.offlineUser,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is ProfileScreenData &&
        other.isAuthenticated == isAuthenticated &&
        other.currentLevel == currentLevel &&
        other.totalXp == totalXp &&
        other.currentStreak == currentStreak &&
        other.longestStreak == longestStreak &&
        other.learnedWordsCount == learnedWordsCount &&
        other.totalQuizzesTaken == totalQuizzesTaken &&
        other.favoritesCount == favoritesCount &&
        other.currentUser?.uid == currentUser?.uid &&
        other.offlineUser?.uid == offlineUser?.uid;
  }

  @override
  int get hashCode {
    return Object.hash(
      isAuthenticated,
      currentLevel,
      totalXp,
      currentStreak,
      longestStreak,
      learnedWordsCount,
      totalQuizzesTaken,
      favoritesCount,
      currentUser?.uid,
      offlineUser?.uid,
    );
  }

  @override
  String toString() {
    return 'ProfileScreenData(isAuthenticated: $isAuthenticated, currentLevel: $currentLevel, totalXp: $totalXp, currentStreak: $currentStreak, longestStreak: $longestStreak, learnedWordsCount: $learnedWordsCount, totalQuizzesTaken: $totalQuizzesTaken, favoritesCount: $favoritesCount)';
  }
}