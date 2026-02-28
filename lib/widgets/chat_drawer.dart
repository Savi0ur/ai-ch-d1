import 'package:flutter/material.dart';
import '../models/chat.dart';

class ChatDrawer extends StatelessWidget {
  final List<Chat> chats;
  final String? activeChatId;
  final VoidCallback onNewChat;
  final ValueChanged<Chat> onSelectChat;
  final ValueChanged<Chat> onDeleteChat;

  const ChatDrawer({
    super.key,
    required this.chats,
    required this.activeChatId,
    required this.onNewChat,
    required this.onSelectChat,
    required this.onDeleteChat,
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
