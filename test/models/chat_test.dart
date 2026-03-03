import 'package:flutter_test/flutter_test.dart';
import 'package:ai_api_app_claude/models/chat.dart';

void main() {
  group('Chat', () {
    test('создаётся с корректными дефолтными значениями', () {
      final now = DateTime.now();
      final chat = Chat(
        id: 'test-id',
        title: 'Test Chat',
        model: 'openai/gpt-4o-mini',
        createdAt: now,
        updatedAt: now,
      );

      expect(chat.id, 'test-id');
      expect(chat.title, 'Test Chat');
      expect(chat.model, 'openai/gpt-4o-mini');
      expect(chat.contextStrategy, 'summarization');
      expect(chat.slidingWindowSize, 20);
      expect(chat.summarizedUpTo, 0);
      expect(chat.systemPrompt, isNull);
      expect(chat.summary, isNull);
      expect(chat.facts, isNull);
      expect(chat.parentChatId, isNull);
      expect(chat.branchMessageIndex, isNull);
      expect(chat.workingMemory, isNull);
    });

    test('принимает все явные значения', () {
      final now = DateTime.now();
      final chat = Chat(
        id: 'id',
        title: 'title',
        model: 'model',
        createdAt: now,
        updatedAt: now,
        systemPrompt: 'You are helpful',
        summary: 'Earlier we discussed...',
        summarizedUpTo: 5,
        contextStrategy: 'sliding_window',
        slidingWindowSize: 10,
        facts: '{"key":"value"}',
        parentChatId: 'parent-id',
        branchMessageIndex: 3,
        workingMemory: '{"goal":"test"}',
      );

      expect(chat.contextStrategy, 'sliding_window');
      expect(chat.slidingWindowSize, 10);
      expect(chat.summarizedUpTo, 5);
      expect(chat.parentChatId, 'parent-id');
      expect(chat.branchMessageIndex, 3);
    });

    test('является веткой когда установлен parentChatId', () {
      final now = DateTime.now();
      final branch = Chat(
        id: 'branch-id',
        title: 'Parent (branch)',
        model: 'openai/gpt-4o-mini',
        createdAt: now,
        updatedAt: now,
        parentChatId: 'parent-id',
        branchMessageIndex: 2,
      );

      expect(branch.parentChatId, isNotNull);
      expect(branch.branchMessageIndex, 2);
    });
  });

  group('ChatMessage', () {
    test('создаётся с корректными полями', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        id: 'msg-id',
        chatId: 'chat-id',
        role: 'user',
        content: 'Hello',
        timestamp: now,
      );

      expect(msg.id, 'msg-id');
      expect(msg.chatId, 'chat-id');
      expect(msg.role, 'user');
      expect(msg.content, 'Hello');
      expect(msg.timestamp, now);
    });

    test('поддерживает role: assistant', () {
      final msg = ChatMessage(
        id: 'id',
        chatId: 'chat',
        role: 'assistant',
        content: 'Hi there!',
        timestamp: DateTime.now(),
      );
      expect(msg.role, 'assistant');
    });

    test('поддерживает role: system', () {
      final msg = ChatMessage(
        id: 'id',
        chatId: 'chat',
        role: 'system',
        content: 'System prompt',
        timestamp: DateTime.now(),
      );
      expect(msg.role, 'system');
    });
  });
}
