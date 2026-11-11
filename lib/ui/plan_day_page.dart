import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../utils/formatting.dart' as fmt;
import 'plan_page.dart' show promptText;
import 'widgets/exercise_picker.dart';
import 'day_preview_page.dart';

class PlanDayPage extends StatelessWidget {
  const PlanDayPage({super.key, required this.dayId});

  final String dayId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final day = state.plan.byId(dayId);
    final scheme = Theme.of(context).colorScheme;

    if (day == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This day was deleted.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(day.name),
        actions: [
          IconButton(
            tooltip: 'See the numbers',
            icon: const Icon(Icons.visibility_outlined),
            onPressed: () => showDayPreview(context, day),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _menu(context, state, day),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExercise(context, state, day),
        icon: const Icon(Icons.add),
        label: const Text('Add exercise'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        children: [
          Text(
            'SCHEDULED ON',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _WeekdayChip(
                      label: fmt.weekdayNames[i - 1],
                      selected: day.weekdays.contains(i),
                      onTap: () => state.toggleWeekday(day, i),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            day.weekdays.isEmpty
                ? 'Not tied to a weekday — start it any time from Today.'
                : 'Runs on ${(day.weekdays.toList()..sort()).map((w) => fmt.weekdayLong[w - 1]).join(' and ')}.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (day.warmup.isNotEmpty) ...[
            const SizedBox(height: 14),
            Card(
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 18,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WARM-UP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            day.warmup,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (day.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  day.notes,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (day.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No exercises yet.\nTap "Add exercise" to build this day.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: day.items.length,
              onReorder: (o, n) => state.reorderPlanItems(day, o, n),
              itemBuilder: (context, i) {
                final item = day.items[i];
                return Padding(
                  key: ValueKey(item.id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ItemCard(
                    item: item,
                    day: day,
                    state: state,
                    index: i,
                    number: day.items.take(i).where((x) => x.active).length + 1,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _addExercise(
    BuildContext context,
    AppState state,
    PlanDay day,
  ) async {
    final id = await pickExercise(context);
    if (id == null || !context.mounted) return;
    final item = state.addPlanItem(day, id);
    if (!context.mounted) return;
    _editItem(context, day, item);
  }

  Future<void> _menu(BuildContext context, AppState state, PlanDay day) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename day'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.subtitles_outlined),
              title: const Text('Edit focus line'),
              subtitle: const Text('e.g. Back · Biceps · Grip'),
              onTap: () => Navigator.of(context).pop('focus'),
            ),
            ListTile(
              leading: const Icon(Icons.local_fire_department_outlined),
              title: const Text('Edit warm-up'),
              onTap: () => Navigator.of(context).pop('warmup'),
            ),
            ListTile(
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: const Text('Day notes'),
              onTap: () => Navigator.of(context).pop('notes'),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete day',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'rename':
        final v = await promptText(context, 'Day name', day.name);
        if (v != null) state.updateDay(day, name: v);
      case 'focus':
        final v = await promptText(context, 'Focus', day.focus);
        if (v != null) state.updateDay(day, focus: v);
      case 'warmup':
        final v = await promptText(context, 'Warm-up', day.warmup);
        if (v != null) state.updateDay(day, warmup: v);
      case 'notes':
        final v = await promptText(context, 'Day notes', day.notes);
        if (v != null) state.updateDay(day, notes: v);
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Delete "${day.name}"?'),
            content: const Text(
              'The day is removed from your plan. Logged workouts are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          state.deleteDay(day.id);
          Navigator.of(context).pop();
        }
    }
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.day,
    required this.state,
    required this.index,
    required this.number,
  });

  final PlanItem item;
  final PlanDay day;
  final AppState state;
  final int index;
  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final def = state.exerciseById(item.exerciseId);
    final timed = def.tracking == TrackingMode.duration;
    final parts = <String>[
      '${item.sets} × ${item.repRange}${timed ? 's' : ''}'
          '${def.repsPerSide ? '/side' : ''}',
      if (item.restSeconds > 0)
        'rest ${fmt.clock(Duration(seconds: item.restSeconds))}',
      if (item.targetWeight != null)
        '${fmt.trimNum(item.targetWeight!)} kg'
            '${def.inverted
                ? ' assist'
                : def.loadIsPerSide
                ? '/side'
                : ''}',
    ];

    return Opacity(
      opacity: item.active ? 1 : 0.45,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _editItem(context, day, item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    item.active ? '$number' : '—',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              def.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                decoration: item.active
                                    ? null
                                    : TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                          if (!item.active) ...[
                            const SizedBox(width: 6),
                            Text(
                              'swapped out',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        parts.join(' · '),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (item.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            item.notes,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.8,
                              ),
                            ),
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
      ),
    );
  }
}

void _editItem(BuildContext context, PlanDay day, PlanItem item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ItemEditor(item: item, day: day),
  );
}

class _ItemEditor extends StatefulWidget {
  const _ItemEditor({required this.item, required this.day});

  final PlanItem item;
  final PlanDay day;

  @override
  State<_ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<_ItemEditor> {
  late final _min = TextEditingController(text: '${widget.item.repMin}');
  late final _max = TextEditingController(text: '${widget.item.repMax}');
  late final _target = TextEditingController(
    text: widget.item.targetWeight == null
        ? ''
        : fmt.trimNum(widget.item.targetWeight!),
  );
  late final _notes = TextEditingController(text: widget.item.notes);
  late final TextEditingController _increment;
  late final TextEditingController _bar;

  @override
  void initState() {
    super.initState();
    final def = context.read<AppState>().exerciseById(widget.item.exerciseId);
    final step = def.incrementKg;
    _increment = TextEditingController(
      text: step == null ? '' : fmt.trimNum(step),
    );
    _bar = TextEditingController(text: fmt.trimNum(def.barKg));
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _target.dispose();
    _notes.dispose();
    _increment.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final item = widget.item;
    final def = state.exerciseById(item.exerciseId);
    final timed = def.tracking == TrackingMode.duration;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                def.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${def.muscle.label} · ${def.equipment.label} · '
                '${def.effortClass.label}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text(
                    'Sets',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: item.sets <= 1
                        ? null
                        : () => state.updatePlanItem(item, sets: item.sets - 1),
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${item.sets}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () =>
                        state.updatePlanItem(item, sets: item.sets + 1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                timed ? 'Target seconds' : 'Target reps',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Double progression: hold the weight until every set hits the '
                'top of this range.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'From'),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) state.updatePlanItem(item, repMin: n);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('–'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'To'),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) state.updatePlanItem(item, repMax: n);
                      },
                    ),
                  ),
                ],
              ),
              if (def.tracking.hasLoad) ...[
                const SizedBox(height: 16),
                Text(
                  def.inverted
                      ? 'Current assistance (kg) — lower is harder'
                      : def.loadSemantics == LoadSemantics.bodyweightOnly
                      ? 'Weight held (kg) — on top of bodyweight'
                      : def.loadIsPerSide
                      ? 'Current load (kg per side)'
                      : 'Current load (kg)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(hintText: 'Leave blank'),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    state.updatePlanItem(
                      item,
                      targetWeight: parsed,
                      clearTarget: v.trim().isEmpty,
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Smallest increment (kg)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'One step on this machine. Saved to the exercise, so every '
                  'routine that uses it steps up the same way.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _increment,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Unknown — the load will not step up on its own',
                    suffixText: 'kg',
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    state.updateExercise(
                      def,
                      incrementKg: parsed,
                      clearIncrement: v.trim().isEmpty,
                    );
                  },
                ),
                if (def.equipment == Equipment.barbell) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Bar weight (kg)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Already part of the weight you log. Used to work out '
                    'plates and warm-ups.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bar,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(suffixText: 'kg'),
                    onChanged: (v) => state.updateExercise(
                      def,
                      barWeight: double.tryParse(v.replaceAll(',', '.')),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Rest between sets',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => state.updatePlanItem(
                      item,
                      restSeconds: def.effortClass.restSeconds,
                    ),
                    child: Text('Default (${def.effortClass.label})'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in const [30, 45, 60, 90, 120, 150, 180, 240])
                    ChoiceChip(
                      label: Text(
                        s < 60
                            ? '${s}s'
                            : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}',
                      ),
                      selected: item.restSeconds == s,
                      onSelected: (_) =>
                          state.updatePlanItem(item, restSeconds: s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Progression note',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notes,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Cues, next step, setup…',
                ),
                onChanged: (v) => state.updatePlanItem(item, notes: v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active in this routine'),
                subtitle: const Text(
                  'Turn off to keep a swapped-out exercise on record',
                ),
                value: item.active,
                onChanged: (v) => state.updatePlanItem(item, active: v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () {
                        state.deletePlanItem(widget.day, item.id);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
