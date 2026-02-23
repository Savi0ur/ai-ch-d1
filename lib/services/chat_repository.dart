import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/chat.dart';

class ChatRepository {
  static const _chatsBoxName = 'chats';
  static const _messagesBoxName = 'messages';
  static const _uuid = Uuid();

  Box<Chat> get _chatsBox => Hive.box<Chat>(_chatsBoxName);
  Box<ChatMessage> get _messagesBox => Hive.box<ChatMessage>(_messagesBoxName);

  static Future<void> init() async {
    Hive.registerAdapter(ChatAdapter());
    Hive.registerAdapter(ChatMessageAdapter());
    await Hive.openBox<Chat>(_chatsBoxName);
    await Hive.openBox<ChatMessage>(_messagesBoxName);
  }

  List<Chat> getChats() {
    final chats = _chatsBox.values.toList();
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  }

  Chat? getChat(String id) {
    return _chatsBox.get(id);
  }

  Chat createChat({required String model, String? systemPrompt}) {
    final chat = Chat(
      id: _uuid.v4(),
      title: 'New Chat',
      model: model,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      systemPrompt: systemPrompt,
    );
    _chatsBox.put(chat.id, chat);
    return chat;
  }

  void updateChat(Chat chat) {
    _chatsBox.put(chat.id, chat);
  }

  void deleteChat(String id) {
    _chatsBox.delete(id);
    // Delete all messages for this chat
    final keysToDelete = _messagesBox.values
        .where((m) => m.chatId == id)
        .map((m) => m.id)
        .toList();
    _messagesBox.deleteAll(keysToDelete);
  }

  List<ChatMessage> getMessages(String chatId) {
    final messages =
        _messagesBox.values.where((m) => m.chatId == chatId).toList();
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  }

  ChatMessage addMessage({
    required String chatId,
    required String role,
    required String content,
  }) {
    final message = ChatMessage(
      id: _uuid.v4(),
      chatId: chatId,
      role: role,
      content: content,
      timestamp: DateTime.now(),
    );
    _messagesBox.put(message.id, message);

    // Update chat's updatedAt and title if first user message
    final chat = getChat(chatId);
    if (chat != null) {
      chat.updatedAt = DateTime.now();
      if (role == 'user' && chat.title == 'New Chat') {
        chat.title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
      }
      updateChat(chat);
    }

    return message;
  }

  void updateMessage(ChatMessage message) {
    _messagesBox.put(message.id, message);
  }
}
