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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNewChat,
                icon: const Icon(Icons.add),
                label: const Text('Новый чат'),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: chats.isEmpty
                ? const Center(child: Text('Нет чатов'))
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

    return ListTile(
      selected: isActive,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.3),
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
        tooltip: 'Удалить',
      ),
      onTap: onTap,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
