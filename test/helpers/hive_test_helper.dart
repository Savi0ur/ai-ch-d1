import 'dart:io';
import 'package:hive/hive.dart';
import 'package:ai_api_app_claude/models/chat.dart';
import 'package:ai_api_app_claude/models/user_memory.dart';

Directory? _testDir;

Future<void> setUpHive() async {
  _testDir = await Directory.systemTemp.createTemp('hive_test_');
  Hive.init(_testDir!.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ChatAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ChatMessageAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserMemoryAdapter());
  await Hive.openBox<Chat>('chats');
  await Hive.openBox<ChatMessage>('messages');
  await Hive.openBox<UserMemory>('memory');
}

Future<void> tearDownHive() async {
  await Hive.close();
  await _testDir?.delete(recursive: true);
  _testDir = null;
}
