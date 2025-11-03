import 'package:equatable/equatable.dart';

class FlashcardSet extends Equatable {
  const FlashcardSet({
    required this.id,
    required this.title,
    required this.cards,
    required this.ownerId,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final List<Flashcard> cards;
  final String ownerId;
  final DateTime updatedAt;

  FlashcardSet copyWith({
    String? id,
    String? title,
    List<Flashcard>? cards,
    String? ownerId,
    DateTime? updatedAt,
  }) {
    return FlashcardSet(
      id: id ?? this.id,
      title: title ?? this.title,
      cards: cards ?? this.cards,
      ownerId: ownerId ?? this.ownerId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'ownerId': ownerId,
      'updatedAt': updatedAt.toIso8601String(),
      'cards': cards.map((card) => card.toMap()).toList(),
    };
  }

  factory FlashcardSet.fromMap(Map<String, dynamic> map) {
    return FlashcardSet(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      cards:
          (map['cards'] as List<dynamic>? ?? [])
              .map(
                (dynamic item) =>
                    Flashcard.fromMap(Map<String, dynamic>.from(item as Map)),
              )
              .toList(),
    );
  }

  @override
  List<Object?> get props => [id, title, cards, ownerId, updatedAt];
}

class Flashcard extends Equatable {
  const Flashcard({
    required this.wordEn,
    required this.wordTr,
    this.isFavorite = false,
  });

  final String wordEn;
  final String wordTr;
  final bool isFavorite;

  Flashcard copyWith({String? wordEn, String? wordTr, bool? isFavorite}) {
    return Flashcard(
      wordEn: wordEn ?? this.wordEn,
      wordTr: wordTr ?? this.wordTr,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {'wordEn': wordEn, 'wordTr': wordTr, 'isFavorite': isFavorite};
  }

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      wordEn: map['wordEn'] as String? ?? '',
      wordTr: map['wordTr'] as String? ?? '',
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [wordEn, wordTr, isFavorite];
}

enum StudyDirection { enToTr, trToEn }
