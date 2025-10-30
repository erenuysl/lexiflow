class UserStatsModel {
  final int level;
  final int xp;
  final int longestStreak;
  final int learnedWords;
  final int quizzesCompleted;

  const UserStatsModel({
    required this.level,
    required this.xp,
    required this.longestStreak,
    required this.learnedWords,
    required this.quizzesCompleted,
  });

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      level: json['level'] ?? 0,
      xp: json['xp'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      learnedWords: json['learnedWords'] ?? 0,
      quizzesCompleted: json['quizzesCompleted'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'xp': xp,
      'longestStreak': longestStreak,
      'learnedWords': learnedWords,
      'quizzesCompleted': quizzesCompleted,
    };
  }

  @override
  String toString() {
    return 'UserStatsModel(level: $level, xp: $xp, longestStreak: $longestStreak, learnedWords: $learnedWords, quizzesCompleted: $quizzesCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserStatsModel &&
        other.level == level &&
        other.xp == xp &&
        other.longestStreak == longestStreak &&
        other.learnedWords == learnedWords &&
        other.quizzesCompleted == quizzesCompleted;
  }

  @override
  int get hashCode {
    return level.hashCode ^
        xp.hashCode ^
        longestStreak.hashCode ^
        learnedWords.hashCode ^
        quizzesCompleted.hashCode;
  }
}