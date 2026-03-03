import 'dart:io';
import 'package:hive/hive.dart';
import 'package:ai_api_app_claude/models/chat.dart';
import 'package:ai_api_app_claude/models/communication_profile.dart';
import 'package:ai_api_app_claude/models/user_memory.dart';

Directory? _testDir;

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ChatAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ChatMessageAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(UserMemoryAdapter());
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(CommunicationProfileAdapter());
  }
}

Future<void> setUpHive() async {
  _testDir = await Directory.systemTemp.createTemp('hive_test_');
  Hive.init(_testDir!.path);
  _registerAdapters();
  await Hive.openBox<Chat>('chats');
  await Hive.openBox<ChatMessage>('messages');
  await Hive.openBox<UserMemory>('memory');
  await Hive.openBox('settings');
}

Future<void> setUpHiveWithProfiles() async {
  _testDir = await Directory.systemTemp.createTemp('hive_test_');
  Hive.init(_testDir!.path);
  _registerAdapters();
  await Hive.openBox<Chat>('chats');
  await Hive.openBox<ChatMessage>('messages');
  await Hive.openBox<UserMemory>('memory');
  await Hive.openBox('settings');
  await Hive.openBox<CommunicationProfile>('profiles');
}

Future<void> tearDownHive() async {
  await Hive.close();
  await _testDir?.delete(recursive: true);
  _testDir = null;
}
