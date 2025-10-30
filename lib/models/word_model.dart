import 'package:hive/hive.dart';
part 'word_model.g.dart';

@HiveType(typeId: 0)
class Word extends HiveObject {
  @HiveField(0)
  final String word;
  @HiveField(1)
  final String meaning;
  @HiveField(2)
  final String example;
  @HiveField(3)
  final String tr; // Turkish translation
  @HiveField(4)
  final String exampleSentence;
  @HiveField(5)
  bool isFavorite;
  @HiveField(6)
  DateTime? nextReviewDate;
  @HiveField(7)
  int interval;
  @HiveField(8)
  int correctStreak;
  @HiveField(9)
  List<String> tags;
  @HiveField(10)
  int srsLevel; // 0 = not learned, 1-5 = learning stages
  @HiveField(11)
  bool isCustom; // true if added by user, false if from default word list
  @HiveField(12)
  final String? category; // Category for quiz filtering

  Word({
    required this.word,
    required this.meaning,
    required this.example,
    this.tr = '',
    this.exampleSentence = '',
    this.isFavorite = false,
    this.nextReviewDate,
    this.interval = 1,
    this.correctStreak = 0,
    this.tags = const [],
    this.srsLevel = 0,
    this.isCustom = false,
    this.category,
  });

  factory Word.fromJson(Map<String, dynamic> json) => Word(
    word: json['word'] ?? '',
    meaning: json['meaning'] ?? '',
    example: json['example'] ?? json['exampleSentence'] ?? '',
    tr: json['tr'] ?? '',
    exampleSentence: json['exampleSentence'] ?? json['example'] ?? '',
    isFavorite: json['isFavorite'] ?? false,
    nextReviewDate:
        json['nextReviewDate'] != null
            ? DateTime.tryParse(json['nextReviewDate'])
            : null,
    interval: json['interval'] ?? 1,
    correctStreak: json['correctStreak'] ?? 0,
    tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    srsLevel: json['srsLevel'] ?? 0,
    isCustom: json['isCustom'] ?? false,
    category: json['category'],
  );

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'meaning': meaning,
      'example': example,
      'tr': tr,
      'exampleSentence': exampleSentence,
      'isFavorite': isFavorite,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
      'interval': interval,
      'correctStreak': correctStreak,
      'tags': tags,
      'srsLevel': srsLevel,
      'isCustom': isCustom,
      'category': category,
    };
  }
}