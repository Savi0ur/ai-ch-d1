import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/api_service.dart';
import '../services/chat_repository.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/request_log_panel.dart';

class ChatScreen extends StatefulWidget {
  final ChatRepository repository;
  final bool isDark;
  final VoidCallback onToggleTheme;

  const ChatScreen({
    super.key,
    required this.repository,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _apiService = ApiService();
  final _scrollController = ScrollController();
  final _stopwatch = Stopwatch();

  // Model selection
  static const _models = <String, String>{
    'openai/gpt-5.2': 'GPT-5.2',
    'openai/gpt-5.1': 'GPT-5.1',
    'openai/gpt-4.1': 'GPT-4.1',
    'openai/o3': 'o3',
    'openai/gpt-4o-mini': 'GPT-4o Mini',
  };
  String _selectedModel = 'openai/gpt-4o-mini';

  // Request Settings
  bool _settingsEnabled = false;
  final _systemPromptController = TextEditingController();
  final _maxTokensController = TextEditingController(text: '1024');
  final _stopSequenceController = TextEditingController();
  double _temperature = 0.7;

  // Chat state
  Chat? _activeChat;
  List<ChatMessage> _messages = [];
  List<Chat> _chats = [];
  bool _isStreaming = false;
  String _streamingContent = '';
  String? _error;
  StreamSubscription<String>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  void _loadChats() {
    setState(() {
      _chats = widget.repository.getChats();
    });
  }

  void _createNewChat() {
    setState(() {
      _activeChat = null;
      _messages = [];
      _streamingContent = '';
      _error = null;
    });
    // Close drawer on mobile
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _selectChat(Chat chat) {
    setState(() {
      _activeChat = chat;
      _messages = widget.repository.getMessages(chat.id);
      _selectedModel = chat.model;
      if (chat.systemPrompt != null && chat.systemPrompt!.isNotEmpty) {
        _systemPromptController.text = chat.systemPrompt!;
        _settingsEnabled = true;
      }
      _streamingContent = '';
      _error = null;
    });
    // Close drawer on mobile
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _deleteChat(Chat chat) {
    widget.repository.deleteChat(chat.id);
    if (_activeChat?.id == chat.id) {
      _activeChat = null;
      _messages = [];
    }
    _loadChats();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isStreaming) return;

    // Create chat if needed
    if (_activeChat == null) {
      final systemPrompt = _settingsEnabled
          ? _systemPromptController.text.trim()
          : null;
      _activeChat = widget.repository.createChat(
        model: _selectedModel,
        systemPrompt: systemPrompt,
      );
    }

    // Save user message
    final userMsg = widget.repository.addMessage(
      chatId: _activeChat!.id,
      role: 'user',
      content: text,
    );

    setState(() {
      _messages.add(userMsg);
      _isStreaming = true;
      _streamingContent = '';
      _error = null;
    });

    _controller.clear();
    _scrollToBottom();

    _stopwatch.reset();
    _stopwatch.start();

    try {
      final stream = _apiService.sendMessageStream(
        _messages,
        model: _selectedModel,
        systemPrompt: _settingsEnabled
            ? _systemPromptController.text.trim()
            : _activeChat!.systemPrompt,
        maxTokens: _settingsEnabled
            ? int.tryParse(_maxTokensController.text.trim())
            : null,
        stopSequence: _settingsEnabled
            ? _stopSequenceController.text.trim()
            : null,
        temperature: _settingsEnabled ? _temperature : null,
      );

      _streamSubscription = stream.listen(
        (delta) {
          setState(() {
            _streamingContent += delta;
          });
          _scrollToBottom();
        },
        onError: (error) {
          _stopwatch.stop();
          setState(() {
            _error = error.toString();
            _isStreaming = false;
          });
        },
        onDone: () {
          _stopwatch.stop();
          if (_streamingContent.isNotEmpty) {
            final assistantMsg = widget.repository.addMessage(
              chatId: _activeChat!.id,
              role: 'assistant',
              content: _streamingContent,
            );
            setState(() {
              _messages.add(assistantMsg);
              _streamingContent = '';
            });
          }
          setState(() {
            _isStreaming = false;
          });
          _loadChats();
        },
      );
    } catch (e) {
      _stopwatch.stop();
      setState(() {
        _error = e.toString();
        _isStreaming = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _cancelStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _apiService.cancelStream();
    if (_streamingContent.isNotEmpty) {
      final assistantMsg = widget.repository.addMessage(
        chatId: _activeChat!.id,
        role: 'assistant',
        content: _streamingContent,
      );
      setState(() {
        _messages.add(assistantMsg);
        _streamingContent = '';
      });
    }
    setState(() {
      _isStreaming = false;
    });
    _loadChats();
  }

  void _showRequestLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: RequestLogPanel(
            apiService: _apiService,
            stopwatch: _stopwatch,
            isStreaming: _isStreaming,
            selectedModel: _selectedModel,
          ),
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Настройки', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedModel,
                  decoration: InputDecoration(
                    labelText: 'Модель',
                    prefixIcon: const Icon(Icons.smart_toy_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: _models.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedModel = value);
                      setSheetState(() {});
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Расширенные настройки',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Switch(
                      value: _settingsEnabled,
                      onChanged: (value) {
                        setState(() => _settingsEnabled = value);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                if (_settingsEnabled) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _systemPromptController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: 'System Prompt',
                      hintText: 'Введите системные инструкции...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _maxTokensController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Tokens',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _stopSequenceController,
                    decoration: const InputDecoration(
                      labelText: 'Stop Sequence',
                      hintText: 'Введите стоп-последовательность...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Temperature: ${_temperature.toStringAsFixed(1)}'),
                      Expanded(
                        child: Slider(
                          value: _temperature,
                          min: 0.0,
                          max: 2.0,
                          divisions: 20,
                          label: _temperature.toStringAsFixed(1),
                          onChanged: (value) {
                            setState(() => _temperature = value);
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _controller.dispose();
    _systemPromptController.dispose();
    _maxTokensController.dispose();
    _stopSequenceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _activeChat?.title ?? 'AI Chat',
          overflow: TextOverflow.ellipsis,
        ),
        leading: isWide
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Чаты',
                ),
              ),
        actions: [
          IconButton(
            onPressed: _createNewChat,
            icon: const Icon(Icons.add),
            tooltip: 'Новый чат',
          ),
          IconButton(
            onPressed: _showSettings,
            icon: const Icon(Icons.tune),
            tooltip: 'Настройки',
          ),
          if (_apiService.lastRequestLog != null)
            IconButton(
              onPressed: _showRequestLog,
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Лог запроса',
            ),
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: widget.isDark ? 'Светлая тема' : 'Тёмная тема',
          ),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              child: ChatDrawer(
                chats: _chats,
                activeChatId: _activeChat?.id,
                onNewChat: _createNewChat,
                onSelectChat: _selectChat,
                onDeleteChat: _deleteChat,
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            ChatDrawer(
              chats: _chats,
              activeChatId: _activeChat?.id,
              onNewChat: _createNewChat,
              onSelectChat: _selectChat,
              onDeleteChat: _deleteChat,
            ),
          if (isWide)
            const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildMessageList()),
                if (_error != null) _buildErrorBanner(),
                ChatInput(
                  controller: _controller,
                  isStreaming: _isStreaming,
                  onSend: _sendMessage,
                  onCancel: _cancelStream,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final allMessages = [..._messages];
    // Add a temporary streaming message
    final hasStreaming = _isStreaming && _streamingContent.isNotEmpty;

    if (allMessages.isEmpty && !hasStreaming) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Начните новый диалог',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: allMessages.length + (hasStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < allMessages.length) {
          return MessageBubble(message: allMessages[index]);
        }
        // Streaming message
        return MessageBubble(
          message: ChatMessage(
            id: 'streaming',
            chatId: _activeChat?.id ?? '',
            role: 'assistant',
            content: _streamingContent,
            timestamp: DateTime.now(),
          ),
          isStreaming: true,
        );
      },
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline,
              size: 18, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _error = null),
          ),
        ],
      ),
    );
  }
}
