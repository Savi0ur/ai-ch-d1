import 'package:flutter/material.dart';

class TaskPhaseBar extends StatefulWidget {
  final String currentPhase;
  final Map<String, String> phaseResults;
  final bool isExtracting;
  final bool canAdvance;
  final VoidCallback onAdvance;

  const TaskPhaseBar({
    super.key,
    required this.currentPhase,
    required this.phaseResults,
    required this.isExtracting,
    required this.canAdvance,
    required this.onAdvance,
  });

  @override
  State<TaskPhaseBar> createState() => _TaskPhaseBarState();
}

class _TaskPhaseBarState extends State<TaskPhaseBar> {
  bool _expanded = false;

  static const _phases = ['planning', 'execution', 'validation', 'done'];
  static const _phaseLabels = {
    'planning': 'Планирование',
    'execution': 'Выполнение',
    'validation': 'Валидация',
    'done': 'Готово',
  };
  static const _phaseIcons = {
    'planning': Icons.edit_note,
    'execution': Icons.play_arrow,
    'validation': Icons.checklist,
    'done': Icons.done_all,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentIndex = _phases.indexOf(widget.currentPhase);

    // Определяем предыдущую фазу для отображения результата
    String? previousPhase;
    if (currentIndex > 0) {
      previousPhase = _phases[currentIndex - 1];
    }
    final previousResult = previousPhase != null
        ? widget.phaseResults[previousPhase]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Степпер
                Expanded(
                  child: Row(
                    children: List.generate(_phases.length * 2 - 1, (i) {
                      if (i.isOdd) {
                        // Коннектор
                        final phaseIdx = i ~/ 2;
                        final done = phaseIdx < currentIndex;
                        return Expanded(
                          child: Container(
                            height: 2,
                            color: done ? colors.primary : colors.outlineVariant,
                          ),
                        );
                      }
                      final phaseIdx = i ~/ 2;
                      final phase = _phases[phaseIdx];
                      final isCurrent = phaseIdx == currentIndex;
                      final isDone = phaseIdx < currentIndex;

                      return _PhaseChip(
                        label: _phaseLabels[phase]!,
                        icon: _phaseIcons[phase]!,
                        isCurrent: isCurrent,
                        isDone: isDone,
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                // Кнопка или спиннер
                if (widget.isExtracting)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (widget.canAdvance)
                  FilledButton.tonalIcon(
                    onPressed: widget.onAdvance,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Завершить этап', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ),
          // Collapsible результат предыдущей фазы
          if (previousResult != null && previousResult.isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Результат: ${_phaseLabels[previousPhase]}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SingleChildScrollView(
                  child: Text(
                    previousResult,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isCurrent;
  final bool isDone;

  const _PhaseChip({
    required this.label,
    required this.icon,
    required this.isCurrent,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Color bgColor;
    Color fgColor;
    if (isDone) {
      bgColor = Colors.green.withValues(alpha: 0.15);
      fgColor = Colors.green;
    } else if (isCurrent) {
      bgColor = colors.primaryContainer;
      fgColor = colors.onPrimaryContainer;
    } else {
      bgColor = colors.surfaceContainerHigh;
      fgColor = colors.onSurfaceVariant.withValues(alpha: 0.5);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone ? Icons.check_circle : icon,
            size: 14,
            color: fgColor,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
