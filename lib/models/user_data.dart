import 'package:hive/hive.dart';

part 'user_data.g.dart';

@HiveType(typeId: 3)
class UserData extends HiveObject {
  @HiveField(0)
  DateTime lastLoginDate;

  @HiveField(1)
  int currentStreak;

  @HiveField(2)
  int totalXp;

  @HiveField(3)
  int currentLevel;

  @HiveField(4)
  int longestStreak;

  @HiveField(5)
  int totalWordsLearned;

  @HiveField(6)
  int totalQuizzesTaken;

  @HiveField(7)
  DateTime? lastFreeQuizDate;

  UserData({
    required this.lastLoginDate,
    this.currentStreak = 0,
    this.totalXp = 0,
    this.currentLevel = 1,
    this.longestStreak = 0,
    this.totalWordsLearned = 0,
    this.totalQuizzesTaken = 0,
    this.lastFreeQuizDate,
  });

  // Calculate XP needed for next level
  int get xpForNextLevel => currentLevel * 100;

  // Calculate progress to next level (0.0 to 1.0)
  double get levelProgress {
    final xpInCurrentLevel = totalXp % 100;
    return xpInCurrentLevel / 100.0;
  }

  // Add XP and check for level up
  bool addXp(int amount) {
    final oldLevel = currentLevel;
    totalXp += amount;
    currentLevel = (totalXp / 100).floor() + 1;
    save();
    return currentLevel > oldLevel; // Returns true if leveled up
  }

  void updateStreak(DateTime today) {
    final lastLogin = DateTime(
      lastLoginDate.year,
      lastLoginDate.month,
      lastLoginDate.day,
    );
    final todayDate = DateTime(today.year, today.month, today.day);
    final difference = todayDate.difference(lastLogin).inDays;

    if (difference == 1) {
      // Consecutive day
      currentStreak++;
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
      }
    } else if (difference > 1) {
      // Streak broken
      currentStreak = 1;
    }
    // If difference == 0, same day, do nothing

    lastLoginDate = today;
    save();
  }
}
