import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/communication_profile.dart';
import '../services/communication_profile_service.dart';
import 'package:uuid/uuid.dart';

class ChatDrawer extends StatelessWidget {
  final List<Chat> chats;
  final String? activeChatId;
  final VoidCallback onNewChat;
  final VoidCallback onNewTask;
  final ValueChanged<Chat> onSelectChat;
  final ValueChanged<Chat> onDeleteChat;
  final CommunicationProfileService profileService;

  const ChatDrawer({
    super.key,
    required this.chats,
    required this.activeChatId,
    required this.onNewChat,
    required this.onNewTask,
    required this.onSelectChat,
    required this.onDeleteChat,
    required this.profileService,
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onNewTask,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.task_alt, size: 20),
                      SizedBox(width: 8),
                      Text('New Task'),
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
            _ProfileSection(profileService: profileService),
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
        leading: chat.isTaskMode
            ? Icon(Icons.task_alt, size: 18, color: colors.primary)
            : isBranch
                ? Icon(Icons.call_split, size: 18, color: colors.onSurfaceVariant)
                : null,
        title: Text(
          chat.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          chat.isTaskMode ? _phaseLabel(chat.taskPhase) : _formatDate(chat.updatedAt),
          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline,
              size: 18, color: colors.onSurfaceVariant),
          onPressed: onDelete,
          tooltip: 'Delete',
        ),
        onTap: onTap,
      ),
    );
  }

  static String _phaseLabel(String? phase) {
    const labels = {
      'planning': 'Планирование',
      'execution': 'Выполнение',
      'validation': 'Валидация',
      'done': 'Готово',
    };
    return labels[phase] ?? '';
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

// ─── Communication Profile Section ─────────────────────────────────────────────

class _ProfileSection extends StatefulWidget {
  final CommunicationProfileService profileService;

  const _ProfileSection({required this.profileService});

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  void _openManager() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ProfileManagerDialog(
        profileService: widget.profileService,
        onChanged: () => setState(() {}),
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profiles = widget.profileService.getProfiles();
    final activeId = widget.profileService.getActiveProfileId();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over_outlined,
                  size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Профиль общения',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _openManager,
                icon: const Icon(Icons.settings_outlined, size: 16),
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Управление профилями',
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButton<String?>(
            value:
                profiles.any((p) => p.id == activeId) ? activeId : null,
            isExpanded: true,
            isDense: true,
            hint: Text(
              'Нет профиля',
              style: TextStyle(
                  fontSize: 13, color: colors.onSurfaceVariant),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'Нет профиля',
                  style: TextStyle(
                      fontSize: 13, color: colors.onSurfaceVariant),
                ),
              ),
              ...profiles.map(
                (p) => DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(
                    p.name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              widget.profileService.setActiveProfileId(value);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

// ─── Profile Manager Dialog ─────────────────────────────────────────────────────

class _ProfileManagerDialog extends StatefulWidget {
  final CommunicationProfileService profileService;
  final VoidCallback onChanged;

  const _ProfileManagerDialog({
    required this.profileService,
    required this.onChanged,
  });

  @override
  State<_ProfileManagerDialog> createState() => _ProfileManagerDialogState();
}

class _ProfileManagerDialogState extends State<_ProfileManagerDialog> {
  void _openEditor([CommunicationProfile? existing]) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ProfileEditorDialog(
        profileService: widget.profileService,
        existing: existing,
      ),
    );
    widget.onChanged();
    setState(() {});
  }

  Future<void> _delete(CommunicationProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить профиль?'),
        content: Text('Профиль «${profile.name}» будет удалён.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    widget.profileService.deleteProfile(profile.id);
    widget.onChanged();
    setState(() {});
  }

  String _shortDesc(CommunicationProfile p) {
    final tone = CommunicationProfile.toneLabels[p.tone] ?? p.tone;
    final depth = CommunicationProfile.depthLabels[p.depth] ?? p.depth;
    final role = CommunicationProfile.roleLabels[p.role] ?? p.role;
    return '$tone · $depth · $role';
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.profileService.getProfiles();

    return AlertDialog(
      title: const Text('Профили общения'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profiles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Нет профилей. Создайте первый.'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: profiles.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = profiles[index];
                    return ListTile(
                      title: Text(p.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        _shortDesc(p),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 18),
                            tooltip: 'Редактировать',
                            onPressed: () => _openEditor(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 18),
                            tooltip: 'Удалить',
                            onPressed: () => _delete(p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Создать профиль'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

// ─── Profile Editor Dialog ──────────────────────────────────────────────────────

class _ProfileEditorDialog extends StatefulWidget {
  final CommunicationProfileService profileService;
  final CommunicationProfile? existing;

  const _ProfileEditorDialog({
    required this.profileService,
    this.existing,
  });

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final TextEditingController _nameCtrl;
  late String _tone;
  late String _depth;
  late String _structure;
  late String _role;
  late String _initiative;

  // Memory fields
  late final TextEditingController _userProfileCtrl;
  late final TextEditingController _userFactsCtrl;
  late final TextEditingController _userInstructionsCtrl;
  late final TextEditingController _userGlossaryCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _tone = p?.tone ?? 'neutral';
    _depth = p?.depth ?? 'standard';
    _structure = p?.structure ?? 'no_structure';
    _role = p?.role ?? 'partner';
    _initiative = p?.initiative ?? 'reactive';

    _userProfileCtrl =
        TextEditingController(text: p?.userProfile ?? '');
    _userFactsCtrl =
        TextEditingController(text: p?.userFacts ?? '');
    _userInstructionsCtrl =
        TextEditingController(text: p?.userInstructions ?? '');
    _userGlossaryCtrl =
        TextEditingController(text: p?.userGlossary ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userProfileCtrl.dispose();
    _userFactsCtrl.dispose();
    _userInstructionsCtrl.dispose();
    _userGlossaryCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final profile = widget.existing ??
        CommunicationProfile(
          id: const Uuid().v4(),
          name: name,
          updatedAt: DateTime.now(),
        );
    profile.name = name;
    profile.tone = _tone;
    profile.depth = _depth;
    profile.structure = _structure;
    profile.role = _role;
    profile.initiative = _initiative;
    profile.updatedAt = DateTime.now();

    final uProfile = _userProfileCtrl.text.trim();
    final uFacts = _userFactsCtrl.text.trim();
    final uInstructions = _userInstructionsCtrl.text.trim();
    final uGlossary = _userGlossaryCtrl.text.trim();
    profile.userProfile = uProfile.isEmpty ? null : uProfile;
    profile.userFacts = uFacts.isEmpty ? null : uFacts;
    profile.userInstructions =
        uInstructions.isEmpty ? null : uInstructions;
    profile.userGlossary = uGlossary.isEmpty ? null : uGlossary;

    widget.profileService.saveProfile(profile);
    Navigator.of(context).pop();
  }

  DropdownButtonFormField<String> _dropdown({
    required String label,
    required String value,
    required Map<String, String> labels,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      borderRadius: BorderRadius.circular(8),
      items: labels.entries
          .map((e) =>
              DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return AlertDialog(
      title: Text(isNew ? 'Новый профиль' : 'Редактировать профиль'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Название
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Название профиля',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // ── Стиль общения
              _dropdown(
                label: 'Тон',
                value: _tone,
                labels: CommunicationProfile.toneLabels,
                onChanged: (v) => setState(() => _tone = v),
              ),
              const SizedBox(height: 10),
              _dropdown(
                label: 'Глубина',
                value: _depth,
                labels: CommunicationProfile.depthLabels,
                onChanged: (v) => setState(() => _depth = v),
              ),
              const SizedBox(height: 10),
              _dropdown(
                label: 'Структура',
                value: _structure,
                labels: CommunicationProfile.structureLabels,
                onChanged: (v) => setState(() => _structure = v),
              ),
              const SizedBox(height: 10),
              _dropdown(
                label: 'Роль',
                value: _role,
                labels: CommunicationProfile.roleLabels,
                onChanged: (v) => setState(() => _role = v),
              ),
              const SizedBox(height: 10),
              _dropdown(
                label: 'Инициативность',
                value: _initiative,
                labels: CommunicationProfile.initiativeLabels,
                onChanged: (v) => setState(() => _initiative = v),
              ),

              // ── Память пользователя
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                'Память пользователя',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userProfileCtrl,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Профиль',
                  hintText: 'Имя, язык, предпочтения...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userFactsCtrl,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Факты (JSON)',
                  hintText: '{"profession": "...", "projects": [...]}',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userInstructionsCtrl,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Всегда-активные инструкции',
                  hintText: 'Инструкции, всегда включаемые в промпт...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _userGlossaryCtrl,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Глоссарий (JSON)',
                  hintText: '{"термин": "определение", ...}',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
