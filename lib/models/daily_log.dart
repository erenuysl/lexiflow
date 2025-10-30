import 'package:hive/hive.dart';
part 'daily_log.g.dart';

@HiveType(typeId: 1)
class DailyLog extends HiveObject {
  @HiveField(0)
  String date; // Format: YYYY-MM-DD

  @HiveField(1)
  List<int> wordIndices; // Indices of words shown today from JSON

  @HiveField(2)
  bool extended; // Whether user watched ad for +5 more words

  DailyLog({
    required this.date,
    required this.wordIndices,
    this.extended = false,
  });

  factory DailyLog.fromJson(Map<String, dynamic> json) => DailyLog(
    date: json['date'],
    wordIndices: (json['wordIndices'] as List).map((e) => e as int).toList(),
    extended: json['extended'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'date': date,
    'wordIndices': wordIndices,
    'extended': extended,
  };
}
