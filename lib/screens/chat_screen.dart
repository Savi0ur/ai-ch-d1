import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/model_config.dart';
import '../services/chat_repository.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/request_log_panel.dart';
import 'chat_controller.dart';

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
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ChatController(repository: widget.repository);
  }

  void _closeDrawerIfOpen() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _onCreateNewChat() {
    _ctrl.createNewChat();
    _closeDrawerIfOpen();
  }

  void _onSelectChat(Chat chat) {
    _ctrl.selectChat(chat);
    _closeDrawerIfOpen();
  }

  Future<void> _onDeleteChat(Chat chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text('Chat "${chat.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _ctrl.deleteChat(chat.id);
  }

  void _onSend() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    _ctrl.sendMessage(text);
    _scrollToBottom();
  }

  void _onCancel() {
    _ctrl.cancelStream();
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
            apiService: _ctrl.apiService,
            stopwatch: _ctrl.stopwatch,
            isStreaming: _ctrl.isStreaming,
            selectedModel: _ctrl.selectedModel,
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
                Text('Settings', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _ctrl.selectedModel,
                  decoration: InputDecoration(
                    labelText: 'Model',
                    prefixIcon: const Icon(Icons.smart_toy_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: ModelConfig.dropdownItems.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _ctrl.selectedModel = value;
                      setSheetState(() {});
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Advanced Settings',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Switch(
                      value: _ctrl.settingsEnabled,
                      onChanged: (value) {
                        _ctrl.settingsEnabled = value;
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                if (_ctrl.settingsEnabled) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl.systemPromptController,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: 'System Prompt',
                      hintText: 'Enter system instructions...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl.maxTokensController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Tokens',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl.stopSequenceController,
                    decoration: const InputDecoration(
                      labelText: 'Stop Sequence',
                      hintText: 'Enter stop sequence...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Temperature: ${_ctrl.temperature.toStringAsFixed(1)}'),
                      Expanded(
                        child: Slider(
                          value: _ctrl.temperature,
                          min: 0.0,
                          max: 2.0,
                          divisions: 20,
                          label: _ctrl.temperature.toStringAsFixed(1),
                          onChanged: (value) {
                            _ctrl.temperature = value;
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
    _ctrl.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        // Auto-scroll when streaming content updates
        if (_ctrl.isStreaming && _ctrl.streamingContent.isNotEmpty) {
          _scrollToBottom();
        }

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text(
              _ctrl.activeChat?.title ?? 'AI Chat',
              overflow: TextOverflow.ellipsis,
            ),
            leading: isWide
                ? null
                : Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      tooltip: 'Chats',
                    ),
                  ),
            actions: [
              IconButton(
                onPressed: _onCreateNewChat,
                icon: const Icon(Icons.add),
                tooltip: 'New chat',
              ),
              IconButton(
                onPressed: _showSettings,
                icon: const Icon(Icons.tune),
                tooltip: 'Settings',
              ),
              if (_ctrl.apiService.lastRequestLog != null)
                IconButton(
                  onPressed: _showRequestLog,
                  icon: const Icon(Icons.receipt_long),
                  tooltip: 'Request log',
                ),
              IconButton(
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  widget.isDark ? Icons.light_mode : Icons.dark_mode,
                ),
                tooltip: widget.isDark ? 'Light theme' : 'Dark theme',
              ),
            ],
          ),
          drawer: isWide
              ? null
              : Drawer(
                  child: ChatDrawer(
                    chats: _ctrl.chats,
                    activeChatId: _ctrl.activeChat?.id,
                    onNewChat: _onCreateNewChat,
                    onSelectChat: _onSelectChat,
                    onDeleteChat: _onDeleteChat,
                  ),
                ),
          body: Row(
            children: [
              if (isWide)
                ChatDrawer(
                  chats: _ctrl.chats,
                  activeChatId: _ctrl.activeChat?.id,
                  onNewChat: _onCreateNewChat,
                  onSelectChat: _onSelectChat,
                  onDeleteChat: _onDeleteChat,
                ),
              if (isWide)
                const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _buildMessageList()),
                    if (_ctrl.isSummarizing) _buildSummarizingBanner(),
                    if (_ctrl.error != null) _buildErrorBanner(),
                    ChatInput(
                      controller: _inputController,
                      isStreaming: _ctrl.isStreaming,
                      onSend: _onSend,
                      onCancel: _onCancel,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    final allMessages = [..._ctrl.messages];
    final hasStreaming = _ctrl.isStreaming && _ctrl.streamingContent.isNotEmpty;

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
              'Start a new conversation',
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
        return MessageBubble(
          message: ChatMessage(
            id: 'streaming',
            chatId: _ctrl.activeChat?.id ?? '',
            role: 'assistant',
            content: _ctrl.streamingContent,
            timestamp: DateTime.now(),
          ),
          isStreaming: true,
        );
      },
    );
  }

  Widget _buildSummarizingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Summarizing context...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontSize: 13,
            ),
          ),
        ],
      ),
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
              _ctrl.error!,
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
            onPressed: _ctrl.clearError,
          ),
        ],
      ),
    );
  }
}
