// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WordAdapter extends TypeAdapter<Word> {
  @override
  final int typeId = 0;

  @override
  Word read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Word(
      word: fields[0] as String,
      meaning: fields[1] as String,
      example: fields[2] as String,
      tr: fields[3] as String,
      exampleSentence: fields[4] as String,
      isFavorite: fields[5] as bool,
      nextReviewDate: fields[6] as DateTime?,
      interval: fields[7] as int,
      correctStreak: fields[8] as int,
      tags: (fields[9] as List).cast<String>(),
      srsLevel: fields[10] as int,
      isCustom: fields[11] as bool,
      category: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Word obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.word)
      ..writeByte(1)
      ..write(obj.meaning)
      ..writeByte(2)
      ..write(obj.example)
      ..writeByte(3)
      ..write(obj.tr)
      ..writeByte(4)
      ..write(obj.exampleSentence)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.nextReviewDate)
      ..writeByte(7)
      ..write(obj.interval)
      ..writeByte(8)
      ..write(obj.correctStreak)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.srsLevel)
      ..writeByte(11)
      ..write(obj.isCustom)
      ..writeByte(12)
      ..write(obj.category);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
