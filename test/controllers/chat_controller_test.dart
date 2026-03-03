import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_api_app_claude/screens/chat_controller.dart';
import 'package:ai_api_app_claude/services/chat_repository.dart';
import 'package:ai_api_app_claude/services/memory_service.dart';
import 'package:ai_api_app_claude/services/api_service.dart';
import 'package:ai_api_app_claude/models/chat.dart';
import '../helpers/hive_test_helper.dart';

/// Фейковый ApiService — не делает HTTP-запросов.
class FakeApiService extends ApiService {
  final List<String> tokensToStream;
  final String summaryResult;
  final String workingMemoryResult;
  final Map<String, String?> userMemoryResult;
  final String factsResult;
  bool sendMessageCalled = false;

  FakeApiService({
    this.tokensToStream = const ['Hello', ' world'],
    this.summaryResult = 'Summary text',
    this.workingMemoryResult = '{"goal":"test goal"}',
    this.userMemoryResult = const {},
    this.factsResult = '{}',
  });

  @override
  Stream<String> sendMessageStream(
    List<ChatMessage> chatMessages, {
    required String model,
    String? systemPrompt,
    int? maxTokens,
    String? stopSequence,
    double? temperature,
  }) async* {
    sendMessageCalled = true;
    for (final token in tokensToStream) {
      yield token;
    }
  }

  @override
  Future<String> summarize(List<ChatMessage> messages, {String? existingSummary}) async {
    return summaryResult;
  }

  @override
  Future<String> extractWorkingMemory(List<ChatMessage> messages, {String? existingWorkingMemory}) async {
    return workingMemoryResult;
  }

  @override
  Future<Map<String, String?>> extractUserMemory(
    List<ChatMessage> messages, {
    String? existingProfile,
    String? existingFacts,
    String? existingInstructions,
    String? existingGlossary,
  }) async {
    return userMemoryResult;
  }

  @override
  Future<String> extractFacts(List<ChatMessage> messages, {String? existingFacts}) async {
    return factsResult;
  }
}

ChatController makeController({FakeApiService? api}) {
  return ChatController(
    repository: ChatRepository(),
    memoryService: MemoryService(),
    apiService: api ?? FakeApiService(),
  );
}

void main() {
  setUp(() async {
    await setUpHive();
  });

  tearDown(() async {
    await tearDownHive();
  });

  group('estimateTokens', () {
    test('пустая строка — 0 токенов', () {
      expect(ChatController.estimateTokens(''), 0);
    });

    test('3 символа — 1 токен', () {
      expect(ChatController.estimateTokens('abc'), 1);
    });

    test('6 символов — 2 токена', () {
      expect(ChatController.estimateTokens('abcdef'), 2);
    });

    test('9 символов — 3 токена', () {
      expect(ChatController.estimateTokens('123456789'), 3);
    });

    test('10 символов — 3 токена (целочисленное деление)', () {
      expect(ChatController.estimateTokens('1234567890'), 3);
    });

    test('300 символов — 100 токенов', () {
      final text = 'a' * 300;
      expect(ChatController.estimateTokens(text), 100);
    });
  });

  group('createNewChat', () {
    test('сбрасывает активный чат', () {
      final ctrl = makeController();
      ctrl.createNewChat();
      expect(ctrl.activeChat, isNull);
    });

    test('очищает список сообщений', () {
      final ctrl = makeController();
      ctrl.createNewChat();
      expect(ctrl.messages, isEmpty);
    });

    test('очищает streamingContent', () {
      final ctrl = makeController();
      ctrl.createNewChat();
      expect(ctrl.streamingContent, isEmpty);
    });

    test('очищает ошибку', () {
      final ctrl = makeController();
      ctrl.createNewChat();
      expect(ctrl.error, isNull);
    });
  });

  group('selectChat', () {
    test('устанавливает activeChat', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');

      ctrl.selectChat(chat);

      expect(ctrl.activeChat?.id, chat.id);
    });

    test('загружает сообщения чата', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      repo.addMessage(chatId: chat.id, role: 'user', content: 'Hi');
      repo.addMessage(chatId: chat.id, role: 'assistant', content: 'Hello');

      ctrl.selectChat(chat);

      expect(ctrl.messages.length, 2);
    });

    test('синхронизирует selectedModel из чата', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-5.2');

      ctrl.selectChat(chat);

      expect(ctrl.selectedModel, 'openai/gpt-5.2');
    });

    test('синхронизирует contextStrategy из чата', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.contextStrategy = 'sliding_window';
      repo.updateChat(chat);

      ctrl.selectChat(chat);

      expect(ctrl.contextStrategy, 'sliding_window');
    });

    test('включает settingsEnabled если у чата есть systemPrompt', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini', systemPrompt: 'Be concise');

      ctrl.selectChat(chat);

      expect(ctrl.settingsEnabled, isTrue);
    });

    test('не включает settingsEnabled если у чата нет systemPrompt', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');

      ctrl.selectChat(chat);

      expect(ctrl.settingsEnabled, isFalse);
    });
  });

  group('deleteChat', () {
    test('сбрасывает activeChat если удалён активный чат', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      ctrl.selectChat(chat);

      ctrl.deleteChat(chat.id);

      expect(ctrl.activeChat, isNull);
      expect(ctrl.messages, isEmpty);
    });

    test('не сбрасывает activeChat если удалён другой чат', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final active = repo.createChat(model: 'openai/gpt-4o-mini');
      final other = repo.createChat(model: 'openai/gpt-4o-mini');
      ctrl.selectChat(active);

      ctrl.deleteChat(other.id);

      expect(ctrl.activeChat?.id, active.id);
    });

    test('удаляет чат из списка chats', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');

      ctrl.deleteChat(chat.id);

      expect(ctrl.chats.any((c) => c.id == chat.id), isFalse);
    });
  });

  group('updateWorkingMemoryManually', () {
    test('обновляет workingMemory активного чата', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      ctrl.selectChat(chat);

      ctrl.updateWorkingMemoryManually('{"goal":"write tests"}');

      expect(ctrl.activeChat!.workingMemory, '{"goal":"write tests"}');
    });

    test('не падает если нет активного чата', () {
      final ctrl = makeController();
      expect(() => ctrl.updateWorkingMemoryManually('{}'), returnsNormally);
    });
  });

  group('buildSystemPrompt', () {
    test('возвращает пустую строку если нет промпта и памяти', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      ctrl.selectChat(chat);

      expect(ctrl.buildSystemPrompt(), isEmpty);
    });

    test('включает systemPrompt чата', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini', systemPrompt: 'Be brief');
      ctrl.selectChat(chat);

      expect(ctrl.buildSystemPrompt(), contains('Be brief'));
    });

    test('включает рабочую память если workingMemoryEnabled', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.workingMemory = '{"goal":"solve bug"}';
      repo.updateChat(chat);
      ctrl.selectChat(chat);
      ctrl.workingMemoryEnabled = true;

      expect(ctrl.buildSystemPrompt(), contains('solve bug'));
    });

    test('не включает рабочую память если workingMemoryEnabled=false', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.workingMemory = '{"goal":"secret task"}';
      repo.updateChat(chat);
      ctrl.selectChat(chat);
      ctrl.workingMemoryEnabled = false;

      expect(ctrl.buildSystemPrompt(), isNot(contains('secret task')));
    });
  });

  group('buildApiMessages — стратегия sliding_window', () {
    test('возвращает последние N сообщений', () async {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.contextStrategy = 'sliding_window';
      chat.slidingWindowSize = 2;
      repo.updateChat(chat);

      for (var i = 0; i < 5; i++) {
        repo.addMessage(chatId: chat.id, role: 'user', content: 'msg$i');
        await Future.delayed(const Duration(milliseconds: 5));
      }

      ctrl.selectChat(chat);
      final result = ctrl.buildApiMessages();

      expect(result.length, 2);
      expect(result[0].content, 'msg3');
      expect(result[1].content, 'msg4');
    });

    test('возвращает все если сообщений меньше N', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.contextStrategy = 'sliding_window';
      chat.slidingWindowSize = 10;
      repo.updateChat(chat);

      repo.addMessage(chatId: chat.id, role: 'user', content: 'msg0');
      repo.addMessage(chatId: chat.id, role: 'assistant', content: 'msg1');

      ctrl.selectChat(chat);
      final result = ctrl.buildApiMessages();

      expect(result.length, 2);
    });
  });

  group('buildApiMessages — стратегия branching', () {
    test('возвращает все сообщения без ограничений', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.contextStrategy = 'branching';
      repo.updateChat(chat);

      for (var i = 0; i < 30; i++) {
        repo.addMessage(chatId: chat.id, role: 'user', content: 'msg$i');
      }

      ctrl.selectChat(chat);
      final result = ctrl.buildApiMessages();

      expect(result.length, 30);
    });
  });

  group('buildApiMessages — стратегия summarization', () {
    test('возвращает все сообщения если нет саммари и summarizedUpTo=0', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.contextStrategy = 'summarization';
      repo.updateChat(chat);

      repo.addMessage(chatId: chat.id, role: 'user', content: 'A');
      repo.addMessage(chatId: chat.id, role: 'assistant', content: 'B');

      ctrl.selectChat(chat);
      final result = ctrl.buildApiMessages();

      expect(result.length, 2);
      expect(result.any((m) => m.role == 'system'), isFalse);
    });

    test('добавляет summary-сообщение если есть саммари', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.contextStrategy = 'summarization';
      chat.summary = 'Ранее обсуждали X';
      chat.summarizedUpTo = 2;
      repo.updateChat(chat);

      repo.addMessage(chatId: chat.id, role: 'user', content: 'msg0');
      repo.addMessage(chatId: chat.id, role: 'assistant', content: 'msg1');
      repo.addMessage(chatId: chat.id, role: 'user', content: 'msg2');
      repo.addMessage(chatId: chat.id, role: 'assistant', content: 'msg3');

      ctrl.selectChat(chat);
      final result = ctrl.buildApiMessages();

      // summary + 2 live messages (index 2 и 3)
      expect(result.length, 3);
      expect(result.first.role, 'system');
      expect(result.first.content, contains('Ранее обсуждали X'));
    });
  });

  group('buildApiMessages — стратегия sticky_facts', () {
    test('добавляет facts как system-сообщение', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.contextStrategy = 'sticky_facts';
      chat.slidingWindowSize = 10;
      chat.facts = '{"language": "Dart"}';
      repo.updateChat(chat);

      repo.addMessage(chatId: chat.id, role: 'user', content: 'Hello');

      ctrl.selectChat(chat);
      final result = ctrl.buildApiMessages();

      expect(result.first.role, 'system');
      expect(result.first.content, contains('Dart'));
    });

    test('не добавляет facts-сообщение если facts пустые', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.contextStrategy = 'sticky_facts';
      chat.slidingWindowSize = 10;
      repo.updateChat(chat);

      repo.addMessage(chatId: chat.id, role: 'user', content: 'Hello');

      ctrl.selectChat(chat);
      final result = ctrl.buildApiMessages();

      expect(result.any((m) => m.role == 'system'), isFalse);
    });
  });

  group('sendMessage', () {
    test('создаёт чат при первом сообщении', () async {
      final ctrl = makeController(api: FakeApiService());

      await ctrl.sendMessage('Привет');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(ctrl.activeChat, isNotNull);
    });

    test('добавляет сообщение пользователя в список', () async {
      final ctrl = makeController(api: FakeApiService());

      await ctrl.sendMessage('Привет');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(ctrl.messages.any((m) => m.role == 'user' && m.content == 'Привет'), isTrue);
    });

    test('добавляет ответ ассистента в список', () async {
      final ctrl = makeController(
        api: FakeApiService(tokensToStream: ['Hello', ' world']),
      );

      await ctrl.sendMessage('Привет');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(ctrl.messages.any((m) => m.role == 'assistant' && m.content == 'Hello world'), isTrue);
    });

    test('isStreaming становится false после завершения', () async {
      final ctrl = makeController(api: FakeApiService());

      await ctrl.sendMessage('Привет');
      // Ждём завершения всех async-колбэков (onDone, addMessage, loadChats)
      await Future.delayed(const Duration(milliseconds: 100));

      expect(ctrl.isStreaming, isFalse);
    });

    test('игнорирует пустое сообщение', () async {
      final api = FakeApiService();
      final ctrl = makeController(api: api);

      await ctrl.sendMessage('');

      expect(api.sendMessageCalled, isFalse);
    });

    test('не отправляет если isStreaming=true', () async {
      final api = FakeApiService();
      final ctrl = makeController(api: api);
      // Напрямую выставляем флаг — имитируем текущий стриминг
      ctrl.isStreaming = true;

      await ctrl.sendMessage('Привет во время стриминга');

      expect(api.sendMessageCalled, isFalse);
    });
  });

  group('clearError', () {
    test('сбрасывает ошибку', () {
      final ctrl = makeController();
      ctrl.error = 'Что-то пошло не так';
      ctrl.clearError();
      expect(ctrl.error, isNull);
    });
  });

  group('createBranch', () {
    test('создаёт ветку и переключается на неё', () {
      final ctrl = makeController();
      final repo = ChatRepository();
      final chat = repo.createChat(model: 'openai/gpt-4o-mini');
      chat.contextStrategy = 'branching';
      repo.updateChat(chat);
      repo.addMessage(chatId: chat.id, role: 'user', content: 'A');
      repo.addMessage(chatId: chat.id, role: 'assistant', content: 'B');
      ctrl.selectChat(chat);

      ctrl.createBranch(0);

      expect(ctrl.activeChat?.parentChatId, chat.id);
    });
  });
}
