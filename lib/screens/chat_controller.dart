import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/model_config.dart';
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

  // Context strategy
  String _contextStrategy = 'summarization';
  String get contextStrategy => _contextStrategy;
  set contextStrategy(String value) {
    _contextStrategy = value;
    if (activeChat != null) {
      activeChat!.contextStrategy = value;
      repository.updateChat(activeChat!);
    }
    notifyListeners();
  }

  int _slidingWindowSize = 20;
  int get slidingWindowSize => _slidingWindowSize;
  set slidingWindowSize(int value) {
    _slidingWindowSize = value;
    if (activeChat != null) {
      activeChat!.slidingWindowSize = value;
      repository.updateChat(activeChat!);
    }
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
  bool isSummarizing = false;
  String streamingContent = '';
  String? error;

  /// Грубая оценка токенов: ~1 токен на 3 символа.
  static int estimateTokens(String text) => text.length ~/ 3;

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
    apiService.clearLogs();
    _resetSettings();
    notifyListeners();
  }

  void selectChat(Chat chat) {
    activeChat = chat;
    messages = repository.getMessages(chat.id);
    _selectedModel = chat.model;
    _contextStrategy = chat.contextStrategy;
    _slidingWindowSize = chat.slidingWindowSize;
    streamingContent = '';
    error = null;
    apiService.clearLogs();
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
    _contextStrategy = activeChat?.contextStrategy ?? 'summarization';
    _slidingWindowSize = activeChat?.slidingWindowSize ?? 20;
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

  /// Формирует список сообщений для API-запроса в зависимости от стратегии контекста.
  List<ChatMessage> _buildApiMessages() {
    final chat = activeChat!;

    switch (chat.contextStrategy) {
      case 'sticky_facts':
        final n = chat.slidingWindowSize;
        final recent = messages.length > n
            ? messages.sublist(messages.length - n)
            : messages;
        if (chat.facts != null && chat.facts!.isNotEmpty) {
          final factsMsg = ChatMessage(
            id: 'facts',
            chatId: chat.id,
            role: 'system',
            content: 'Known facts:\n${chat.facts}',
            timestamp: DateTime.now(),
          );
          return [factsMsg, ...recent];
        }
        return recent;

      case 'sliding_window':
        final n = chat.slidingWindowSize;
        return messages.length > n
            ? messages.sublist(messages.length - n)
            : messages;

      case 'branching':
        return messages; // все сообщения, пользователь сам управляет ветками

      case 'summarization':
      default:
        final liveMessages = messages.sublist(chat.summarizedUpTo);
        if (chat.summary == null || chat.summary!.isEmpty) return liveMessages;
        final summaryMsg = ChatMessage(
          id: 'summary',
          chatId: chat.id,
          role: 'system',
          content: 'Summary of earlier conversation:\n${chat.summary}',
          timestamp: DateTime.now(),
        );
        return [summaryMsg, ...liveMessages];
    }
  }

  /// Диспатчер стратегий управления контекстом.
  Future<void> _manageContext() async {
    switch (activeChat!.contextStrategy) {
      case 'summarization':
        await _summarizeIfNeeded();
      case 'sliding_window':
      case 'sticky_facts':
      case 'branching':
        break; // обрезка только при формировании API-запроса в _buildApiMessages
    }
  }

  /// Sticky Facts: извлекает key-value facts из последних сообщений.
  Future<void> _updateFacts() async {
    final n = activeChat!.slidingWindowSize;
    final recentMessages = messages.length > n
        ? messages.sublist(messages.length - n)
        : messages;
    final newFacts = await apiService.extractFacts(
      recentMessages,
      existingFacts: activeChat!.facts,
    );
    activeChat!.facts = newFacts;
    repository.updateChat(activeChat!);
  }

  /// Branching: создаёт ветку от указанного сообщения.
  void createBranch(int messageIndex) {
    final branch = repository.createBranch(
      sourceChat: activeChat!,
      messageIndex: messageIndex,
      messages: messages,
    );
    loadChats();
    selectChat(branch);
  }

  /*
   * Логика суммаризации контекста
   * ─────────────────────────────
   * Перед каждым API-запросом оцениваем общее количество токенов:
   *   system prompt + существующее саммари + живые сообщения + maxTokens (на ответ).
   * Если это превышает 85% контекстного окна модели — обрезаем старые сообщения:
   *   1. Идём с конца живых сообщений и набираем те, что влезают в «бюджет»
   *      (contextWindow * 0.85 − maxTokens − system − summary − 500 запас).
   *   2. Остальные (более старые) отправляем на суммаризацию лёгкой моделью
   *      (GPT-4o Mini), которая возвращает краткое саммари.
   *   3. Саммари сохраняется в `chat.summary`; `chat.summarizedUpTo` сдвигается
   *      вперёд, чтобы обрезанные сообщения больше не отправлялись.
   */
  Future<void> _summarizeIfNeeded() async {
    final chat = activeChat!;
    final contextWindow = ModelConfig.getContextWindow(selectedModel);
    if (contextWindow == null) return;

    final maxTokens = settingsEnabled
        ? (int.tryParse(maxTokensController.text.trim()) ?? 1024)
        : 1024;

    final systemPrompt = settingsEnabled
        ? systemPromptController.text.trim()
        : (chat.systemPrompt ?? '');
    final systemTokens = estimateTokens(systemPrompt);
    final summaryTokens =
        chat.summary != null ? estimateTokens(chat.summary!) : 0;

    final liveMessages = messages.sublist(chat.summarizedUpTo);
    int liveTokens = 0;
    for (final m in liveMessages) {
      liveTokens += estimateTokens(m.content);
    }

    final totalEstimate =
        systemTokens + summaryTokens + liveTokens + maxTokens;
    final threshold = (contextWindow * 0.85).toInt();

    if (totalEstimate <= threshold) return;

    // Нужна суммаризация
    isSummarizing = true;
    notifyListeners();

    try {
      const summaryReserve = 500;
      final budget =
          threshold - maxTokens - systemTokens - summaryTokens - summaryReserve;

      // Идём с конца, определяем какие сообщения оставить (минимум последнее)
      int keepTokens = 0;
      int keepFrom = liveMessages.length;
      for (int i = liveMessages.length - 1; i >= 0; i--) {
        final t = estimateTokens(liveMessages[i].content);
        if (keepTokens + t > budget) break;
        keepTokens += t;
        keepFrom = i;
      }
      // Гарантируем что хотя бы последнее сообщение остаётся (не суммаризируется)
      if (keepFrom >= liveMessages.length) {
        keepFrom = liveMessages.length - 1;
      }

      // Если нечего суммаризировать — последнее сообщение само по себе
      // превышает контекстное окно, суммаризация не поможет
      if (keepFrom <= 0) {
        throw Exception(
          'Сообщение слишком длинное для контекстного окна модели '
          '($contextWindow токенов). Сократите текст или выберите '
          'модель с большим контекстом.',
        );
      }

      final toSummarize = liveMessages.sublist(0, keepFrom);
      final newSummary = await apiService.summarize(
        toSummarize,
        existingSummary: chat.summary,
      );
      chat.summary = newSummary;
      chat.summarizedUpTo += keepFrom;
      repository.updateChat(chat);
    } finally {
      isSummarizing = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.isEmpty || isStreaming) return;

    // Создаём чат если нужно
    if (activeChat == null) {
      final systemPrompt = settingsEnabled
          ? systemPromptController.text.trim()
          : null;
      activeChat = repository.createChat(
        model: selectedModel,
        systemPrompt: systemPrompt,
      );
      activeChat!.contextStrategy = _contextStrategy;
      activeChat!.slidingWindowSize = _slidingWindowSize;
      repository.updateChat(activeChat!);
    }

    // Сохраняем сообщение пользователя
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
      // Управляем контекстом в зависимости от выбранной стратегии
      await _manageContext();

      final apiMessages = _buildApiMessages();

      final stream = apiService.sendMessageStream(
        apiMessages,
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
        onDone: () async {
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

          // Sticky Facts: извлекаем facts после каждого ответа
          if (activeChat?.contextStrategy == 'sticky_facts') {
            try {
              await _updateFacts();
            } catch (_) {
              // Не прерываем поток из-за ошибки извлечения facts
            }
          }
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
