import 'package:hive/hive.dart';

class Chat extends HiveObject {
  String id;
  String title;
  String model;
  DateTime createdAt;
  DateTime updatedAt;
  String? systemPrompt;
  String? summary;
  int summarizedUpTo;
  String contextStrategy;     // 'summarization' | 'sliding_window' | 'sticky_facts' | 'branching'
  int slidingWindowSize;      // N для sliding window и sticky facts (по умолчанию 20)
  String? facts;              // JSON-строка с key-value facts
  String? parentChatId;       // ID родительского чата (для веток)
  int? branchMessageIndex;    // Индекс сообщения-checkpoint (для веток)

  Chat({
    required this.id,
    required this.title,
    required this.model,
    required this.createdAt,
    required this.updatedAt,
    this.systemPrompt,
    this.summary,
    this.summarizedUpTo = 0,
    this.contextStrategy = 'summarization',
    this.slidingWindowSize = 20,
    this.facts,
    this.parentChatId,
    this.branchMessageIndex,
  });
}

class ChatMessage extends HiveObject {
  String id;
  String chatId;
  String role; // 'user' | 'assistant' | 'system'
  String content;
  DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

class ChatAdapter extends TypeAdapter<Chat> {
  @override
  final int typeId = 0;

  @override
  Chat read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Chat(
      id: fields[0] as String,
      title: fields[1] as String,
      model: fields[2] as String,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      systemPrompt: fields[5] as String?,
      summary: fields[6] as String?,
      summarizedUpTo: (fields[7] as int?) ?? 0,
      contextStrategy: (fields[8] as String?) ?? 'summarization',
      slidingWindowSize: (fields[9] as int?) ?? 20,
      facts: fields[10] as String?,
      parentChatId: fields[11] as String?,
      branchMessageIndex: fields[12] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, Chat obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.model)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.systemPrompt)
      ..writeByte(6)
      ..write(obj.summary)
      ..writeByte(7)
      ..write(obj.summarizedUpTo)
      ..writeByte(8)
      ..write(obj.contextStrategy)
      ..writeByte(9)
      ..write(obj.slidingWindowSize)
      ..writeByte(10)
      ..write(obj.facts)
      ..writeByte(11)
      ..write(obj.parentChatId)
      ..writeByte(12)
      ..write(obj.branchMessageIndex);
  }
}

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 1;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      id: fields[0] as String,
      chatId: fields[1] as String,
      role: fields[2] as String,
      content: fields[3] as String,
      timestamp: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.chatId)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.timestamp);
  }
}
