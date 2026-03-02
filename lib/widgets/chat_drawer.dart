import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/user_memory.dart';
import '../services/memory_service.dart';

class ChatDrawer extends StatelessWidget {
  final List<Chat> chats;
  final String? activeChatId;
  final VoidCallback onNewChat;
  final ValueChanged<Chat> onSelectChat;
  final ValueChanged<Chat> onDeleteChat;
  final MemoryService memoryService;

  const ChatDrawer({
    super.key,
    required this.chats,
    required this.activeChatId,
    required this.onNewChat,
    required this.onSelectChat,
    required this.onDeleteChat,
    required this.memoryService,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 280,
      color: colors.surfaceContainerLow,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onNewChat,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 20),
                    SizedBox(width: 8),
                    Text('New Chat'),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: chats.isEmpty
                ? const Center(child: Text('No chats'))
                : ListView.builder(
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final isActive = chat.id == activeChatId;
                      return _ChatTile(
                        chat: chat,
                        isActive: isActive,
                        onTap: () => onSelectChat(chat),
                        onDelete: () => onDeleteChat(chat),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          _UserMemorySection(memoryService: memoryService),
        ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Chat chat;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ChatTile({
    required this.chat,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final isBranch = chat.parentChatId != null;

    return Padding(
      padding: EdgeInsets.only(left: isBranch ? 16 : 0),
      child: ListTile(
        selected: isActive,
        selectedTileColor: colors.primaryContainer.withValues(alpha: 0.3),
        leading: isBranch
            ? Icon(Icons.call_split, size: 18, color: colors.onSurfaceVariant)
            : null,
        title: Text(
          chat.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          _formatDate(chat.updatedAt),
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, size: 18, color: colors.onSurfaceVariant),
          onPressed: onDelete,
          tooltip: 'Delete',
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _UserMemorySection extends StatefulWidget {
  final MemoryService memoryService;

  const _UserMemorySection({required this.memoryService});

  @override
  State<_UserMemorySection> createState() => _UserMemorySectionState();
}

class _UserMemorySectionState extends State<_UserMemorySection> {
  void _openEditor() async {
    final memory = widget.memoryService.getMemory();
    await showDialog<void>(
      context: context,
      builder: (context) => _MemoryEditorDialog(
        memory: memory,
        onSave: (updated) {
          widget.memoryService.saveMemory(updated);
          setState(() {});
        },
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final memory = widget.memoryService.getMemory();
    final hasAny = widget.memoryService.hasMemory;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'User Memory',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _openEditor,
                icon: const Icon(Icons.edit_outlined, size: 16),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Edit memory',
              ),
            ],
          ),
          if (hasAny) ...[
            const SizedBox(height: 4),
            if (memory.profile != null && memory.profile!.isNotEmpty)
              Text(
                memory.profile!,
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ] else
            Text(
              'No memory yet',
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _MemoryEditorDialog extends StatefulWidget {
  final UserMemory memory;
  final ValueChanged<UserMemory> onSave;

  const _MemoryEditorDialog({required this.memory, required this.onSave});

  @override
  State<_MemoryEditorDialog> createState() => _MemoryEditorDialogState();
}

class _MemoryEditorDialogState extends State<_MemoryEditorDialog> {
  late final TextEditingController _profileCtrl;
  late final TextEditingController _factsCtrl;
  late final TextEditingController _instructionsCtrl;
  late final TextEditingController _glossaryCtrl;

  @override
  void initState() {
    super.initState();
    _profileCtrl = TextEditingController(text: widget.memory.profile ?? '');
    _factsCtrl = TextEditingController(text: widget.memory.facts ?? '');
    _instructionsCtrl =
        TextEditingController(text: widget.memory.instructions ?? '');
    _glossaryCtrl = TextEditingController(text: widget.memory.glossary ?? '');
  }

  @override
  void dispose() {
    _profileCtrl.dispose();
    _factsCtrl.dispose();
    _instructionsCtrl.dispose();
    _glossaryCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.memory;
    updated.profile = _profileCtrl.text.trim().isEmpty
        ? null
        : _profileCtrl.text.trim();
    updated.facts = _factsCtrl.text.trim().isEmpty
        ? null
        : _factsCtrl.text.trim();
    updated.instructions = _instructionsCtrl.text.trim().isEmpty
        ? null
        : _instructionsCtrl.text.trim();
    updated.glossary = _glossaryCtrl.text.trim().isEmpty
        ? null
        : _glossaryCtrl.text.trim();
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('User Memory'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _profileCtrl,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Profile',
                  hintText: 'Name, language, preferences...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _factsCtrl,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Facts (JSON)',
                  hintText: '{"profession": "...", "projects": [...]}',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructionsCtrl,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Always-on instructions',
                  hintText: 'Instructions always included in prompts...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _glossaryCtrl,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Glossary (JSON)',
                  hintText: '{"term": "definition", ...}',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
