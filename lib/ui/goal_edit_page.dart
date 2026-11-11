import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../utils/formatting.dart' as fmt;
import 'widgets/exercise_picker.dart';

/// Creates a goal, or edits one in place. The same form does both — a goal
/// you cannot correct afterwards is worse than no goal at all.
///
/// Everything is held locally and committed on Save, so backing out of a
/// half-filled form leaves nothing behind.
class GoalEditPage extends StatefulWidget {
  const GoalEditPage({super.key, this.goalId});

  /// Null when creating.
  final String? goalId;

  @override
  State<GoalEditPage> createState() => _GoalEditPageState();
}

class _GoalEditPageState extends State<GoalEditPage> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _notes;

  GoalType _type = GoalType.general;
  GoalStatus _status = GoalStatus.active;
  bool _primary = false;
  String? _testExerciseId;
  int _testInterval = 14;

  late List<GoalMarker> _markers;
  late List<Milestone> _milestones;
  late Set<String> _dayIds;

  bool get _isNew => widget.goalId == null;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final goal = widget.goalId == null ? null : state.goalById(widget.goalId!);

    _title = TextEditingController(text: goal?.title ?? '');
    _target = TextEditingController(text: goal?.target ?? '');
    _notes = TextEditingController(text: goal?.notes ?? '');

    if (goal != null) {
      _type = goal.type;
      _status = goal.status;
      _primary = goal.primary;
      _testExerciseId = goal.testExerciseId;
      _testInterval = goal.testIntervalDays;
    }
    // Copied, not aliased: Cancel has to mean cancel. The entries themselves
    // are kept by identity so a milestone's tick survives an edit.
    _markers = [...?goal?.markers];
    _milestones = [...?goal?.milestones];
    _dayIds = state.plan.days
        .where((d) => goal != null && d.goalIds.contains(goal.id))
        .map((d) => d.id)
        .toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final goal = widget.goalId == null ? null : state.goalById(widget.goalId!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New goal' : 'Edit ${goal?.code ?? 'goal'}'),
        actions: [
          TextButton(
            onPressed: () => _save(context, state, goal),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              labelText: 'Goal',
              hintText: 'First unassisted pull-up',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _target,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What counts as done',
              hintText: '1 clean rep from a dead hang',
            ),
          ),
          const SizedBox(height: 22),
          _Label('KIND'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in GoalType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _Label('STATUS'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in GoalStatus.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _status == s,
                  onSelected: (_) => setState(() {
                    _status = s;
                    // Only a goal you are actually chasing can be the one
                    // everything else is judged against.
                    if (s != GoalStatus.active) _primary = false;
                  }),
                ),
            ],
          ),
          if (_status == GoalStatus.active)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Primary goal'),
              subtitle: const Text(
                'Routine changes are judged against this one, and it is '
                'owed first when a week slips',
              ),
              value: _primary,
              onChanged: (v) => setState(() => _primary = v),
            ),
          const SizedBox(height: 12),
          _Label('PROGRESS MARKERS'),
          const SizedBox(height: 4),
          Text(
            'Numbers read straight off the log, so the goal moves on its own '
            'as you train.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          if (_markers.isEmpty)
            _Empty(
              text: 'No markers yet — the goal will just be a note to self.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _markers.length; i++)
                    _MarkerTile(
                      marker: _markers[i],
                      onTap: () => _editMarker(i),
                      onRemove: () => setState(() => _markers.removeAt(i)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _addExerciseMarker,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Track a movement'),
              ),
              if (!_markers.any((m) => m.metric == MarkerMetric.bodyweight))
                OutlinedButton.icon(
                  onPressed: () => setState(
                    () => _markers.add(state.suggestBodyweightMarker()),
                  ),
                  icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                  label: const Text('Track bodyweight'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _Label('MILESTONES'),
          const SizedBox(height: 10),
          if (_milestones.isEmpty)
            _Empty(text: 'Optional stepping stones on the way there.')
          else
            Card(
              child: Column(
                children: [
                  for (final m in _milestones)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        m.done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: m.done ? scheme.primary : scheme.outline,
                      ),
                      title: Text(m.label),
                      subtitle: m.eta.isEmpty ? null : Text(m.eta),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _milestones.remove(m)),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addMilestone,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add milestone'),
          ),
          const SizedBox(height: 24),
          _Label('PERIODIC TEST'),
          const SizedBox(height: 4),
          Text(
            'Some goals are only really measured by attempting them. The '
            'primary goal offers this on Today when it is due.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(
                    _testExerciseId == null
                        ? 'No test movement'
                        : state.exerciseName(_testExerciseId!),
                  ),
                  subtitle: const Text('The attempt that counts'),
                  trailing: _testExerciseId == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () =>
                              setState(() => _testExerciseId = null),
                        ),
                  onTap: _pickTestExercise,
                ),
                if (_testExerciseId != null)
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Attempt every'),
                    trailing: DropdownButton<int>(
                      value: _testInterval,
                      underline: const SizedBox.shrink(),
                      items: const [7, 10, 14, 21, 28]
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text('$d days'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _testInterval = v ?? _testInterval),
                    ),
                  ),
              ],
            ),
          ),
          if (state.plan.days.isNotEmpty) ...[
            const SizedBox(height: 24),
            _Label('TRAINED ON'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in state.plan.days)
                  FilterChip(
                    label: Text(d.name),
                    selected: _dayIds.contains(d.id),
                    onSelected: (on) => setState(
                      () => on ? _dayIds.add(d.id) : _dayIds.remove(d.id),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          TextField(
            controller: _notes,
            maxLines: null,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes',
              alignLabelWithHint: true,
            ),
          ),
          if (!_isNew && goal != null) ...[
            const SizedBox(height: 32),
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                onPressed: () => _delete(context, state, goal),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete this goal'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ actions

  Future<void> _addExerciseMarker() async {
    final id = await pickExercise(context, title: 'Track a movement');
    if (id == null || !mounted) return;
    final state = context.read<AppState>();
    setState(() => _markers.add(state.suggestMarker(state.exerciseById(id))));
  }

  Future<void> _pickTestExercise() async {
    final id = await pickExercise(context, title: 'Test movement');
    if (id == null || !mounted) return;
    setState(() => _testExerciseId = id);
  }

  Future<void> _editMarker(int index) async {
    final edited = await showDialog<GoalMarker>(
      context: context,
      builder: (_) => _MarkerDialog(marker: _markers[index]),
    );
    if (edited == null || !mounted) return;
    setState(() => _markers[index] = edited);
  }

  Future<void> _addMilestone() async {
    final made = await showDialog<Milestone>(
      context: context,
      builder: (_) => const _MilestoneDialog(),
    );
    if (made == null || !mounted) return;
    setState(() => _milestones.add(made));
  }

  void _save(BuildContext context, AppState state, Goal? goal) {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the goal a name first.')),
      );
      return;
    }

    final saved =
        goal ??
        state.createGoal(
          title: title,
          type: _type,
          target: _target.text,
          notes: _notes.text,
          status: _status,
          primary: _primary,
          testExerciseId: _testExerciseId,
          testIntervalDays: _testInterval,
          markers: _markers,
          milestones: _milestones,
        );

    if (goal != null) {
      state.updateGoal(
        goal,
        title: title,
        type: _type,
        target: _target.text,
        notes: _notes.text,
        status: _status,
        primary: _primary,
        testExerciseId: _testExerciseId,
        testIntervalDays: _testInterval,
        markers: _markers,
        milestones: _milestones,
      );
    }
    state.setGoalDays(saved, _dayIds);
    Navigator.of(context).pop(saved.id);
  }

  Future<void> _delete(BuildContext context, AppState state, Goal goal) async {
    final navigator = Navigator.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${goal.code}?'),
        content: Text(
          '"${goal.title}" and its markers go for good. Your training log is '
          'untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    state.deleteGoal(goal);
    // Back past the detail page too — it has nothing left to show.
    navigator.pop('deleted');
  }
}

// ------------------------------------------------------------------- pieces

class _MarkerTile extends StatelessWidget {
  const _MarkerTile({
    required this.marker,
    required this.onTap,
    required this.onRemove,
  });

  final GoalMarker marker;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: Icon(
        marker.lowerIsBetter ? Icons.trending_down : Icons.trending_up,
        size: 20,
        color: scheme.primary,
      ),
      title: Text(marker.label),
      subtitle: Text(
        '${marker.metric.label} · from ${fmt.trimNum(marker.baseline)}'
        '${marker.unit}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: onRemove,
      ),
    );
  }
}

class _MarkerDialog extends StatefulWidget {
  const _MarkerDialog({required this.marker});

  final GoalMarker marker;

  @override
  State<_MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<_MarkerDialog> {
  late final TextEditingController _label = TextEditingController(
    text: widget.marker.label,
  );
  late final TextEditingController _baseline = TextEditingController(
    text: fmt.trimNum(widget.marker.baseline),
  );
  late bool _lower = widget.marker.lowerIsBetter;

  @override
  void dispose() {
    _label.dispose();
    _baseline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Marker'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseline,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Starting point',
              suffixText: widget.marker.unit,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Lower is better'),
            subtitle: const Text('Assistance weight and bodyweight go down'),
            value: _lower,
            onChanged: (v) => setState(() => _lower = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final m = widget.marker;
            Navigator.of(context).pop(
              GoalMarker(
                label: _label.text.trim().isEmpty
                    ? m.label
                    : _label.text.trim(),
                metric: m.metric,
                exerciseId: m.exerciseId,
                baseline: double.tryParse(_baseline.text.trim()) ?? m.baseline,
                lowerIsBetter: _lower,
                unit: m.unit,
              ),
            );
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _MilestoneDialog extends StatefulWidget {
  const _MilestoneDialog();

  @override
  State<_MilestoneDialog> createState() => _MilestoneDialogState();
}

class _MilestoneDialogState extends State<_MilestoneDialog> {
  final _label = TextEditingController();
  final _eta = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _eta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Milestone'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Milestone',
              hintText: 'Assistance down to 40 kg',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _eta,
            decoration: const InputDecoration(
              labelText: 'Rough timing',
              hintText: '~3-4 months',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final label = _label.text.trim();
            if (label.isEmpty) return;
            Navigator.of(
              context,
            ).pop(Milestone(label: label, eta: _eta.text.trim()));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
