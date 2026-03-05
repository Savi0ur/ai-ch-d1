import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/model_config.dart';
import '../services/chat_repository.dart';
import '../services/communication_profile_service.dart';
import '../services/memory_service.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import '../widgets/request_log_panel.dart';
import '../widgets/task_phase_bar.dart';
import '../widgets/working_memory_panel.dart';
import 'chat_controller.dart';

class ChatScreen extends StatefulWidget {
  final ChatRepository repository;
  final MemoryService memoryService;
  final CommunicationProfileService profileService;
  final bool isDark;
  final VoidCallback onToggleTheme;

  const ChatScreen({
    super.key,
    required this.repository,
    required this.memoryService,
    required this.profileService,
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
    _ctrl = ChatController(
      repository: widget.repository,
      memoryService: widget.memoryService,
      profileService: widget.profileService,
    );
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

  void _onCreateNewTask() {
    _ctrl.createNewTaskChat();
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

  Future<void> _onBranchFromMessage(int messageIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create branch?'),
        content: const Text(
          'A new chat will be created with messages up to this point.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _ctrl.createBranch(messageIndex);
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
                  initialValue: _ctrl.contextStrategy,
                  decoration: InputDecoration(
                    labelText: 'Context Strategy',
                    prefixIcon: const Icon(Icons.memory),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(
                      value: 'summarization',
                      child: Text('Summarization'),
                    ),
                    DropdownMenuItem(
                      value: 'sliding_window',
                      child: Text('Sliding Window'),
                    ),
                    DropdownMenuItem(
                      value: 'sticky_facts',
                      child: Text('Sticky Facts'),
                    ),
                    DropdownMenuItem(
                      value: 'branching',
                      child: Text('Branching'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _ctrl.contextStrategy = value;
                      setSheetState(() {});
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (_ctrl.contextStrategy == 'sliding_window' ||
                    _ctrl.contextStrategy == 'sticky_facts')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: TextEditingController(
                        text: _ctrl.slidingWindowSize.toString(),
                      ),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Window Size (messages)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                      ),
                      onChanged: (value) {
                        final n = int.tryParse(value);
                        if (n != null && n > 0) {
                          _ctrl.slidingWindowSize = n;
                        }
                      },
                    ),
                  ),
                if (_ctrl.contextStrategy == 'branching')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Long-press a message to create a branch from that point.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                const SizedBox(height: 8),
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

  void _showInvariantsEditor() {
    showDialog(
      context: context,
      builder: (context) => _InvariantsEditorDialog(
        invariants: _ctrl.parsedTaskInvariants,
        onAdd: (text) => _ctrl.addTaskInvariant(text),
        onRemove: (index) => _ctrl.removeTaskInvariant(index),
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
              _ctrl.isTaskMode
                  ? '${_ctrl.activeChat?.title ?? 'Task'} — ${_phaseLabel(_ctrl.taskPhase)}'
                  : (_ctrl.activeChat?.title ?? 'AI Chat'),
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
                    onNewTask: _onCreateNewTask,
                    onSelectChat: _onSelectChat,
                    onDeleteChat: _onDeleteChat,
                    profileService: widget.profileService,
                  ),
                ),
          body: Row(
            children: [
              if (isWide)
                ChatDrawer(
                  chats: _ctrl.chats,
                  activeChatId: _ctrl.activeChat?.id,
                  onNewChat: _onCreateNewChat,
                  onNewTask: _onCreateNewTask,
                  onSelectChat: _onSelectChat,
                  onDeleteChat: _onDeleteChat,
                  profileService: widget.profileService,
                ),
              if (isWide)
                const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    if (_ctrl.isTaskMode)
                      TaskPhaseBar(
                        currentPhase: _ctrl.taskPhase ?? 'planning',
                        phaseResults: _ctrl.parsedPhaseResults,
                        isExtracting: _ctrl.isExtractingPhaseResult,
                        canAdvance: !_ctrl.isStreaming &&
                            !_ctrl.isExtractingPhaseResult &&
                            _ctrl.taskPhase != 'done' &&
                            _ctrl.messages.length > (_ctrl.activeChat?.summarizedUpTo ?? 0),
                        onAdvance: () => _ctrl.advanceTaskPhase(),
                        invariants: _ctrl.parsedTaskInvariants,
                        onEditInvariants: _showInvariantsEditor,
                      ),
                    Expanded(child: _buildMessageList()),
                    if (_ctrl.isSummarizing) _buildSummarizingBanner(),
                    if (_ctrl.error != null) _buildErrorBanner(),
                    if (!_ctrl.isTaskMode) WorkingMemoryPanel(
                        workingMemory: _ctrl.activeChat?.workingMemory,
                        isUpdating: _ctrl.isUpdatingMemory,
                        enabled: _ctrl.workingMemoryEnabled,
                        onToggle: (value) {
                          _ctrl.workingMemoryEnabled = value;
                        },
                        onEdit: _ctrl.updateWorkingMemoryManually,
                        onClear: () => _ctrl.updateWorkingMemoryManually(''),
                      ),
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
      final isTask = _ctrl.isTaskMode;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTask ? Icons.task_alt : Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isTask && _ctrl.taskPhase == 'planning'
                  ? 'Describe the task to start planning'
                  : 'Start a new conversation',
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
          return MessageBubble(
            message: allMessages[index],
            onBranch: _ctrl.activeChat?.contextStrategy == 'branching'
                ? () => _onBranchFromMessage(index)
                : null,
          );
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

  static String _phaseLabel(String? phase) {
    const labels = {
      'planning': 'Planning',
      'execution': 'Execution',
      'validation': 'Validation',
      'done': 'Done',
    };
    return labels[phase] ?? phase ?? '';
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

class _InvariantsEditorDialog extends StatefulWidget {
  final List<String> invariants;
  final void Function(String) onAdd;
  final void Function(int) onRemove;

  const _InvariantsEditorDialog({
    required this.invariants,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<_InvariantsEditorDialog> createState() =>
      _InvariantsEditorDialogState();
}

class _InvariantsEditorDialogState extends State<_InvariantsEditorDialog> {
  final _textController = TextEditingController();
  late List<String> _invariants;

  @override
  void initState() {
    super.initState();
    _invariants = List.from(widget.invariants);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _add() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onAdd(text);
    setState(() {
      _invariants = List.from(_invariants)..add(text);
      _textController.clear();
    });
  }

  void _remove(int index) {
    widget.onRemove(index);
    setState(() {
      _invariants = List.from(_invariants)..removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Task invariants'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hard constraints the assistant must follow in every phase.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'New invariant...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _add,
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_invariants.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _invariants.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (context, index) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(
                      Icons.lock_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                    title: Text(
                      _invariants[index],
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => _remove(index),
                      tooltip: 'Delete',
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
