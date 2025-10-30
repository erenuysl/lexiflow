// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserDataAdapter extends TypeAdapter<UserData> {
  @override
  final int typeId = 3;

  @override
  UserData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserData(
      lastLoginDate: fields[0] as DateTime,
      currentStreak: fields[1] as int,
      totalXp: fields[2] as int,
      currentLevel: fields[3] as int,
      longestStreak: fields[4] as int,
      totalWordsLearned: fields[5] as int,
      totalQuizzesTaken: fields[6] as int,
      lastFreeQuizDate: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserData obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.lastLoginDate)
      ..writeByte(1)
      ..write(obj.currentStreak)
      ..writeByte(2)
      ..write(obj.totalXp)
      ..writeByte(3)
      ..write(obj.currentLevel)
      ..writeByte(4)
      ..write(obj.longestStreak)
      ..writeByte(5)
      ..write(obj.totalWordsLearned)
      ..writeByte(6)
      ..write(obj.totalQuizzesTaken)
      ..writeByte(7)
      ..write(obj.lastFreeQuizDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
