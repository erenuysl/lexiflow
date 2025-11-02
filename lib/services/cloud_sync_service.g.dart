// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_sync_service.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedUserDataAdapter extends TypeAdapter<CachedUserData> {
  @override
  final int typeId = 10;

  @override
  CachedUserData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedUserData(
      learnedWordsCount: fields[0] as int,
      currentStreak: fields[1] as int,
      totalQuizzesCompleted: fields[2] as int,
      totalXp: fields[3] as int,
      achievements: (fields[4] as Map).cast<String, dynamic>(),
      lastSyncTime: fields[5] as DateTime,
      isDirty: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CachedUserData obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.learnedWordsCount)
      ..writeByte(1)
      ..write(obj.currentStreak)
      ..writeByte(2)
      ..write(obj.totalQuizzesCompleted)
      ..writeByte(3)
      ..write(obj.totalXp)
      ..writeByte(4)
      ..write(obj.achievements)
      ..writeByte(5)
      ..write(obj.lastSyncTime)
      ..writeByte(6)
      ..write(obj.isDirty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedUserDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
