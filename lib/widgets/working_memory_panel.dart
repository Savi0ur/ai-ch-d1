import 'dart:convert';
import 'package:flutter/material.dart';

class WorkingMemoryPanel extends StatefulWidget {
  final String? workingMemory;
  final bool isUpdating;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onEdit;
  final VoidCallback onClear;

  const WorkingMemoryPanel({
    super.key,
    required this.workingMemory,
    required this.isUpdating,
    required this.enabled,
    required this.onToggle,
    required this.onEdit,
    required this.onClear,
  });

  @override
  State<WorkingMemoryPanel> createState() => _WorkingMemoryPanelState();
}

class _WorkingMemoryPanelState extends State<WorkingMemoryPanel> {
  bool _expanded = false;

  Map<String, dynamic>? _parse() {
    if (widget.workingMemory == null || widget.workingMemory!.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(widget.workingMemory!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _showEditDialog() {
    final controller =
        TextEditingController(text: widget.workingMemory ?? '{}');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Working Memory'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '{"goal": "", "steps": [], ...}',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              widget.onEdit(controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final parsed = _parse();

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
        color: colors.surfaceContainerLow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 16,
                    color: widget.enabled
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Working Memory',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.enabled
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  if (widget.isUpdating) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colors.primary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Switch(
                    value: widget.enabled,
                    onChanged: widget.onToggle,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_more
                        : Icons.chevron_right,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (parsed != null) ...[
                    if (parsed['goal'] != null)
                      _Field('Goal', parsed['goal'].toString()),
                    if (parsed['current_step'] != null)
                      _Field('Current step', parsed['current_step'].toString()),
                    if (parsed['steps'] is List &&
                        (parsed['steps'] as List).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Steps:',
                        style: TextStyle(
                            fontSize: 11, color: colors.onSurfaceVariant),
                      ),
                      ...((parsed['steps'] as List).asMap().entries.map((e) =>
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Text(
                              '${e.key + 1}. ${e.value}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ))),
                    ],
                    if (parsed['results'] != null &&
                        parsed['results'].toString().isNotEmpty)
                      _Field('Results', parsed['results'].toString()),
                    if (parsed['notes'] != null &&
                        parsed['notes'].toString().isNotEmpty)
                      _Field('Notes', parsed['notes'].toString()),
                  ] else if (widget.workingMemory != null &&
                      widget.workingMemory!.isNotEmpty) ...[
                    Text(
                      widget.workingMemory!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ] else ...[
                    Text(
                      'No working memory yet. Enable the toggle and send a message.',
                      style: TextStyle(
                          fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: _showEditDialog,
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Edit', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: widget.onClear,
                        icon: const Icon(Icons.clear, size: 14),
                        label: const Text('Clear', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor:
                              Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(fontSize: 12, color: colors.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
