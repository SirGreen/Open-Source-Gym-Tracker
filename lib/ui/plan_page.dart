import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../utils/formatting.dart' as fmt;
import 'plan_day_page.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Plan'),
            Text(
              state.plan.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Rename plan',
            icon: const Icon(Icons.drive_file_rename_outline),
            onPressed: () async {
              final name = await promptText(
                context,
                'Plan name',
                state.plan.name,
              );
              if (name != null) state.renamePlan(name);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDay(context, state),
        icon: const Icon(Icons.add),
        label: const Text('Add day'),
      ),
      body: Column(
        children: [
          _RotationStrip(state: state),
          const Divider(height: 1),
          Expanded(
            child: state.plan.days.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.list_alt,
                            size: 48,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No training days yet.\nAdd your first day to build the split.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                    itemCount: state.plan.days.length,
                    onReorder: state.reorderDays,
                    itemBuilder: (context, i) {
                      final day = state.plan.days[i];
                      return Padding(
                        key: ValueKey(day.id),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayCard(day: day, state: state, index: i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addDay(BuildContext context, AppState state) async {
    final name = await promptText(context, 'New training day', '');
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final day = state.addDay(name);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PlanDayPage(dayId: day.id)));
  }
}

/// The week at a glance — which routine sits on which day, and where the rest
/// days fall.
class _RotationStrip extends StatelessWidget {
  const _RotationStrip({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          for (var wd = 1; wd <= 7; wd++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Text(
                      fmt.weekdayNames[wd - 1],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Builder(
                      builder: (context) {
                        final days = state.plan.daysForWeekday(wd);
                        final rest = days.isEmpty;
                        return Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: rest
                                ? scheme.surfaceContainerLow
                                : scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            rest
                                ? 'Rest'
                                : days
                                      .map((d) => d.name.split(' ').first)
                                      .join('\n/ '),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.5,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: rest
                                  ? scheme.onSurfaceVariant
                                  : scheme.onPrimaryContainer,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.state, required this.index});

  final PlanDay day;
  final AppState state;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final weekdays = day.weekdays.toList()..sort();
    final active = day.activeItems;
    final goals = day.goalIds
        .map(state.goalById)
        .whereType<Goal>()
        .map((g) => g.code)
        .toList();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PlanDayPage(dayId: day.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            day.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final wd in weekdays) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              fmt.weekdayName(wd),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (day.focus.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        day.focus,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${active.length} exercises · '
                      '${active.fold(0, (a, i) => a + i.sets)} sets'
                      '${day.items.length > active.length ? ' · ${day.items.length - active.length} swapped out' : ''}'
                      '${goals.isEmpty ? '' : ' · ${goals.join(' ')}'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.drag_handle,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> promptText(
  BuildContext context,
  String title,
  String initial, {
  bool numeric = false,
  String? hint,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textCapitalization: numeric
            ? TextCapitalization.none
            : TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
