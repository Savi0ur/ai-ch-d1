import 'package:flutter_test/flutter_test.dart';
import 'package:ai_api_app_claude/services/chat_repository.dart';
import 'package:ai_api_app_claude/models/chat.dart';
import '../helpers/hive_test_helper.dart';

void main() {
  late ChatRepository repo;

  setUp(() async {
    await setUpHive();
    repo = ChatRepository();
  });

  tearDown(() async {
    await tearDownHive();
  });

  group('createChat', () {
    test('создаёт чат с дефолтным заголовком "New Chat"', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      expect(chat.title, 'New Chat');
      expect(chat.model, 'openai/gpt-4o-mini');
    });

    test('сохраняет чат в хранилище', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      expect(repo.getChat(chat.id), isNotNull);
    });

    test('генерирует уникальные id', () {
      final a = repo.createChat(model: 'openai/gpt-4o-mini');
      final b = repo.createChat(model: 'openai/gpt-4o-mini');
      expect(a.id, isNot(equals(b.id)));
    });

    test('сохраняет systemPrompt', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini', systemPrompt: 'Be concise');
      expect(chat.systemPrompt, 'Be concise');
    });
  });

  group('getChats', () {
    test('возвращает пустой список если чатов нет', () {
      expect(repo.getChats(), isEmpty);
    });

    test('возвращает чаты отсортированные по updatedAt убыванию', () async {
      final a = repo.createChat(model: 'openai/gpt-4o-mini');
      await Future.delayed(const Duration(milliseconds: 10));
      final b = repo.createChat(model: 'openai/gpt-4o-mini');

      final chats = repo.getChats();
      expect(chats.first.id, b.id);
      expect(chats.last.id, a.id);
    });

    test('возвращает все созданные чаты', () {
      repo.createChat(model: 'openai/gpt-4o-mini');
      repo.createChat(model: 'openai/gpt-4o-mini');
      repo.createChat(model: 'openai/gpt-4o-mini');
      expect(repo.getChats().length, 3);
    });
  });

  group('getChat', () {
    test('возвращает чат по id', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      expect(repo.getChat(chat.id)?.id, chat.id);
    });

    test('возвращает null для несуществующего id', () {
      expect(repo.getChat('nonexistent'), isNull);
    });
  });

  group('deleteChat', () {
    test('удаляет чат из хранилища', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.deleteChat(chat.id);
      expect(repo.getChat(chat.id), isNull);
    });

    test('удаляет все сообщения чата', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: chat.id, role: 'user', content: 'Hello');
      repo.addMessage(chatId: chat.id, role: 'assistant', content: 'Hi');

      repo.deleteChat(chat.id);

      expect(repo.getMessages(chat.id), isEmpty);
    });

    test('не удаляет сообщения других чатов', () {
      final a = repo.createChat(model: 'openai/gpt-4o-mini');
      final b = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: a.id, role: 'user', content: 'A message');
      repo.addMessage(chatId: b.id, role: 'user', content: 'B message');

      repo.deleteChat(a.id);

      expect(repo.getMessages(b.id).length, 1);
    });
  });

  group('addMessage', () {
    test('создаёт сообщение с корректными полями', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      final msg = repo.addMessage(chatId: chat.id, role: 'user', content: 'Hello');

      expect(msg.chatId, chat.id);
      expect(msg.role, 'user');
      expect(msg.content, 'Hello');
      expect(msg.id, isNotEmpty);
    });

    test('устанавливает заголовок чата из первого сообщения пользователя', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: chat.id, role: 'user', content: 'Как дела?');

      expect(repo.getChat(chat.id)!.title, 'Как дела?');
    });

    test('обрезает заголовок если длиннее 30 символов', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      const longText = 'Это очень длинное сообщение, которое точно длиннее тридцати символов';
      repo.addMessage(chatId: chat.id, role: 'user', content: longText);

      final title = repo.getChat(chat.id)!.title;
      expect(title.length, lessThanOrEqualTo(33)); // 30 + '...'
      expect(title, endsWith('...'));
    });

    test('не меняет заголовок для второго сообщения пользователя', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: chat.id, role: 'user', content: 'Первое');
      repo.addMessage(chatId: chat.id, role: 'user', content: 'Второе');

      expect(repo.getChat(chat.id)!.title, 'Первое');
    });

    test('не меняет заголовок для сообщения ассистента', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: chat.id, role: 'assistant', content: 'Привет!');

      expect(repo.getChat(chat.id)!.title, 'New Chat');
    });
  });

  group('getMessages', () {
    test('возвращает пустой список для нового чата', () {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      expect(repo.getMessages(chat.id), isEmpty);
    });

    test('возвращает сообщения отсортированные по timestamp', () async {
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: chat.id, role: 'user', content: 'Первое');
      await Future.delayed(const Duration(milliseconds: 10));
      repo.addMessage(chatId: chat.id, role: 'assistant', content: 'Второе');

      final msgs = repo.getMessages(chat.id);
      expect(msgs[0].content, 'Первое');
      expect(msgs[1].content, 'Второе');
    });

    test('возвращает только сообщения указанного чата', () {
      final a = repo.createChat(model: 'openai/gpt-4o-mini');
      final b = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: a.id, role: 'user', content: 'Для A');
      repo.addMessage(chatId: b.id, role: 'user', content: 'Для B');

      expect(repo.getMessages(a.id).length, 1);
      expect(repo.getMessages(a.id).first.content, 'Для A');
    });
  });

  group('createBranch', () {
    test('создаёт новый чат с parentChatId', () {
      final source = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: source.id, role: 'user', content: 'A');
      repo.addMessage(chatId: source.id, role: 'assistant', content: 'B');
      repo.addMessage(chatId: source.id, role: 'user', content: 'C');
      final messages = repo.getMessages(source.id);

      final branch = repo.createBranch(sourceChat: source, messageIndex: 1, messages: messages);

      expect(branch.parentChatId, source.id);
      expect(branch.branchMessageIndex, 1);
    });

    test('заголовок ветки содержит "(branch)"', () {
      final source = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: source.id, role: 'user', content: 'Hi');
      final messages = repo.getMessages(source.id);

      final branch = repo.createBranch(sourceChat: source, messageIndex: 0, messages: messages);

      expect(branch.title, contains('branch'));
    });

    test('копирует сообщения до messageIndex включительно', () async {
      final source = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: source.id, role: 'user', content: 'msg0');
      await Future.delayed(const Duration(milliseconds: 5));
      repo.addMessage(chatId: source.id, role: 'assistant', content: 'msg1');
      await Future.delayed(const Duration(milliseconds: 5));
      repo.addMessage(chatId: source.id, role: 'user', content: 'msg2');
      final messages = repo.getMessages(source.id);

      final branch = repo.createBranch(sourceChat: source, messageIndex: 1, messages: messages);
      final branchMessages = repo.getMessages(branch.id);

      expect(branchMessages.length, 2);
      expect(branchMessages[0].content, 'msg0');
      expect(branchMessages[1].content, 'msg1');
    });

    test('ветка имеет новые id для сообщений', () {
      final source = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: source.id, role: 'user', content: 'Hello');
      final messages = repo.getMessages(source.id);
      final srcMsgId = messages.first.id;

      final branch = repo.createBranch(sourceChat: source, messageIndex: 0, messages: messages);
      final branchMessages = repo.getMessages(branch.id);

      expect(branchMessages.first.id, isNot(equals(srcMsgId)));
    });

    test('наследует модель и systemPrompt из исходного чата', () {
      final source = repo.createChat(model: 'openai/gpt-5.2', systemPrompt: 'Be brief');
      repo.addMessage(chatId: source.id, role: 'user', content: 'Hi');
      final messages = repo.getMessages(source.id);

      final branch = repo.createBranch(sourceChat: source, messageIndex: 0, messages: messages);

      expect(branch.model, 'openai/gpt-5.2');
      expect(branch.systemPrompt, 'Be brief');
    });
  });
}
