import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/chat_repository.dart';

class ChatController extends ChangeNotifier {
  final ChatRepository repository;
  final ApiService apiService = ApiService();
  final Stopwatch stopwatch = Stopwatch();

  // Settings controllers (owned by controller, disposed here)
  final systemPromptController = TextEditingController();
  final maxTokensController = TextEditingController(text: '1024');
  final stopSequenceController = TextEditingController();

  // Model selection
  String _selectedModel = 'openai/gpt-4o-mini';
  String get selectedModel => _selectedModel;
  set selectedModel(String value) {
    _selectedModel = value;
    notifyListeners();
  }

  // Request settings
  bool _settingsEnabled = false;
  bool get settingsEnabled => _settingsEnabled;
  set settingsEnabled(bool value) {
    _settingsEnabled = value;
    notifyListeners();
  }

  double _temperature = 0.7;
  double get temperature => _temperature;
  set temperature(double value) {
    _temperature = value;
    notifyListeners();
  }

  // Chat state
  Chat? activeChat;
  List<ChatMessage> messages = [];
  List<Chat> chats = [];
  bool isStreaming = false;
  String streamingContent = '';
  String? error;

  StreamSubscription<String>? _streamSubscription;

  ChatController({required this.repository}) {
    loadChats();
  }

  void loadChats() {
    chats = repository.getChats();
    notifyListeners();
  }

  void createNewChat() {
    activeChat = null;
    messages = [];
    streamingContent = '';
    error = null;
    _resetSettings();
    notifyListeners();
  }

  void selectChat(Chat chat) {
    activeChat = chat;
    messages = repository.getMessages(chat.id);
    _selectedModel = chat.model;
    streamingContent = '';
    error = null;
    _resetSettings();
    if (chat.systemPrompt != null && chat.systemPrompt!.isNotEmpty) {
      systemPromptController.text = chat.systemPrompt!;
      _settingsEnabled = true;
    }
    notifyListeners();
  }

  void _resetSettings() {
    _settingsEnabled = false;
    _temperature = 0.7;
    maxTokensController.text = '1024';
    stopSequenceController.clear();
    systemPromptController.clear();
  }

  void deleteChat(String chatId) {
    repository.deleteChat(chatId);
    if (activeChat?.id == chatId) {
      activeChat = null;
      messages = [];
    }
    loadChats();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty || isStreaming) return;

    // Create chat if needed
    if (activeChat == null) {
      final systemPrompt = settingsEnabled
          ? systemPromptController.text.trim()
          : null;
      activeChat = repository.createChat(
        model: selectedModel,
        systemPrompt: systemPrompt,
      );
    }

    // Save user message
    final userMsg = repository.addMessage(
      chatId: activeChat!.id,
      role: 'user',
      content: text,
    );

    messages.add(userMsg);
    isStreaming = true;
    streamingContent = '';
    error = null;
    notifyListeners();

    stopwatch.reset();
    stopwatch.start();

    try {
      final stream = apiService.sendMessageStream(
        messages,
        model: selectedModel,
        systemPrompt: settingsEnabled
            ? systemPromptController.text.trim()
            : activeChat!.systemPrompt,
        maxTokens: settingsEnabled
            ? int.tryParse(maxTokensController.text.trim())
            : null,
        stopSequence: settingsEnabled
            ? stopSequenceController.text.trim()
            : null,
        temperature: settingsEnabled ? temperature : null,
      );

      _streamSubscription = stream.listen(
        (delta) {
          streamingContent += delta;
          notifyListeners();
        },
        onError: (error) {
          stopwatch.stop();
          this.error = error.toString();
          isStreaming = false;
          notifyListeners();
        },
        onDone: () {
          stopwatch.stop();
          if (streamingContent.isNotEmpty) {
            final assistantMsg = repository.addMessage(
              chatId: activeChat!.id,
              role: 'assistant',
              content: streamingContent,
            );
            messages.add(assistantMsg);
            streamingContent = '';
          }
          isStreaming = false;
          loadChats();
        },
      );
    } catch (e) {
      stopwatch.stop();
      error = e.toString();
      isStreaming = false;
      notifyListeners();
    }
  }

  void cancelStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    apiService.cancelStream();
    if (streamingContent.isNotEmpty) {
      final assistantMsg = repository.addMessage(
        chatId: activeChat!.id,
        role: 'assistant',
        content: streamingContent,
      );
      messages.add(assistantMsg);
      streamingContent = '';
    }
    isStreaming = false;
    loadChats();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    systemPromptController.dispose();
    maxTokensController.dispose();
    stopSequenceController.dispose();
    super.dispose();
  }
}
