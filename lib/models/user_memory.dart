import 'package:hive/hive.dart';

class UserMemory extends HiveObject {
  String? profile;       // имя, язык, предпочтения
  String? facts;         // JSON: профессия, проекты, интересы
  String? instructions;  // всегда-включённые инструкции
  String? glossary;      // JSON: термин → определение
  DateTime updatedAt;

  UserMemory({
    this.profile,
    this.facts,
    this.instructions,
    this.glossary,
    required this.updatedAt,
  });
}

class UserMemoryAdapter extends TypeAdapter<UserMemory> {
  @override
  final int typeId = 2;

  @override
  UserMemory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserMemory(
      profile: fields[0] as String?,
      facts: fields[1] as String?,
      instructions: fields[2] as String?,
      glossary: fields[3] as String?,
      updatedAt: (fields[4] as DateTime?) ?? DateTime.now(),
    );
  }

  @override
  void write(BinaryWriter writer, UserMemory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.profile)
      ..writeByte(1)
      ..write(obj.facts)
      ..writeByte(2)
      ..write(obj.instructions)
      ..writeByte(3)
      ..write(obj.glossary)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }
}
