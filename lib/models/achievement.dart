import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
  final int progress;
  final int target;
  final int xpReward;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
    required this.progress,
    required this.target,
    required this.xpReward,
  });

  Achievement copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    bool? unlocked,
    int? progress,
    int? target,
    int? xpReward,
  }) {
    return Achievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      unlocked: unlocked ?? this.unlocked,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      xpReward: xpReward ?? this.xpReward,
    );
  }

  // Progress percentage (0.0 to 1.0)
  double get progressPercentage {
    if (target == 0) return 0.0;
    return (progress / target).clamp(0.0, 1.0);
  }

  // Check if achievement should be unlocked
  bool get shouldBeUnlocked => progress >= target;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'unlocked': unlocked,
      'progress': progress,
      'target': target,
      'xpReward': xpReward,
    };
  }

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      icon: Icons.star, // Default icon, will be set by service
      unlocked: json['unlocked'] as bool? ?? false,
      progress: json['progress'] as int? ?? 0,
      target: json['target'] as int? ?? 1,
      xpReward: json['xpReward'] as int? ?? 50,
    );
  }

  @override
  String toString() {
    return 'Achievement(id: $id, title: $title, unlocked: $unlocked, progress: $progress/$target)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Achievement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Predefined achievement types
enum AchievementType {
  learnedWords,
  streak,
  quizzes,
}

// Achievement definitions
class AchievementDefinitions {
  static const Map<String, Map<String, dynamic>> definitions = {
    'learned_words_100': {
      'title': '100 Kelime',
      'description': '100 kelime öğren',
      'icon': Icons.book,
      'target': 100,
      'xpReward': 200,
      'type': AchievementType.learnedWords,
    },
    'streak_10': {
      'title': '10 Günlük Seri',
      'description': '10 gün üst üste pratik yap',
      'icon': Icons.local_fire_department,
      'target': 10,
      'xpReward': 150,
      'type': AchievementType.streak,
    },
    'quizzes_25': {
      'title': '25 Quiz',
      'description': '25 quiz tamamla',
      'icon': Icons.quiz,
      'target': 25,
      'xpReward': 100,
      'type': AchievementType.quizzes,
    },
  };

  static Achievement createAchievement(String id, {
    int progress = 0,
    bool unlocked = false,
  }) {
    final definition = definitions[id];
    if (definition == null) {
      throw ArgumentError('Unknown achievement ID: $id');
    }

    return Achievement(
      id: id,
      title: definition['title'] as String,
      description: definition['description'] as String,
      icon: definition['icon'] as IconData,
      unlocked: unlocked,
      progress: progress,
      target: definition['target'] as int,
      xpReward: definition['xpReward'] as int,
    );
  }

  static List<Achievement> getAllAchievements({
    Map<String, int>? progressMap,
    Set<String>? unlockedSet,
  }) {
    return definitions.keys.map((id) {
      return createAchievement(
        id,
        progress: progressMap?[id] ?? 0,
        unlocked: unlockedSet?.contains(id) ?? false,
      );
    }).toList();
  }
}