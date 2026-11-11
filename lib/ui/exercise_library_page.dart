import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../utils/formatting.dart' as fmt;
import 'widgets/exercise_picker.dart';

class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({super.key});

  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _query.trim().toLowerCase();
    final list = state.exercisesSorted
        .where(
          (e) =>
              q.isEmpty ||
              e.name.toLowerCase().contains(q) ||
              e.muscle.label.toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final id = await pickExercise(context, title: 'New exercise');
          if (id == null || !context.mounted) return;
          _edit(context, state.exerciseById(id));
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final e = list[i];
                final showHeader = i == 0 || list[i - 1].muscle != e.muscle;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showHeader)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Text(
                          e.muscle.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ListTile(
                      title: Text(e.name),
                      subtitle: Text(_subtitle(state, e)),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _edit(context, e),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(AppState state, ExerciseDef e) {
    final uses = state.plan.days
        .expand((d) => d.items)
        .where((i) => i.exerciseId == e.id)
        .length;
    return [
      e.equipment.label,
      if (e.inverted) 'lower = harder',
      if (e.loadIsPerSide) 'per side',
      if (e.baseLoadKg != null) 'base ${fmt.trimNum(e.baseLoadKg!)} kg',
      if (e.stackUnit == StackUnit.lb) 'lb stack',
      if (uses > 0) 'in $uses plan ${uses == 1 ? 'slot' : 'slots'}',
    ].join(' · ');
  }

  void _edit(BuildContext context, ExerciseDef exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ExerciseEditor(exercise: exercise),
    );
  }
}

class _ExerciseEditor extends StatefulWidget {
  const _ExerciseEditor({required this.exercise});

  final ExerciseDef exercise;

  @override
  State<_ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<_ExerciseEditor> {
  late final _name = TextEditingController(text: widget.exercise.name);
  late final _base = TextEditingController(
    text: widget.exercise.baseLoadKg == null
        ? ''
        : fmt.trimNum(widget.exercise.baseLoadKg!),
  );
  late final _increment = TextEditingController(
    text: widget.exercise.incrementKg == null
        ? ''
        : fmt.trimNum(widget.exercise.incrementKg!),
  );
  late final _bar = TextEditingController(
    text: fmt.trimNum(widget.exercise.barWeight),
  );
  late final _notes = TextEditingController(text: widget.exercise.notes);

  @override
  void dispose() {
    _name.dispose();
    _base.dispose();
    _increment.dispose();
    _bar.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ex = widget.exercise;
    final scheme = Theme.of(context).colorScheme;
    // Pairs made from the other end. Skipped when this exercise names it too,
    // or the same pair would show up twice.
    final linkedIn = state
        .linkedFrom(ex.id)
        .where((e) => !ex.alternativeIds.contains(e.id))
        .toList();

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
                'Edit exercise',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => state.updateExercise(ex, name: v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MuscleGroup>(
                initialValue: ex.muscle,
                decoration: const InputDecoration(labelText: 'Muscle group'),
                items: [
                  for (final m in MuscleGroup.values)
                    DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (v) => state.updateExercise(ex, muscle: v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<Equipment>(
                initialValue: ex.equipment,
                decoration: const InputDecoration(labelText: 'Equipment'),
                items: [
                  for (final e in Equipment.values)
                    DropdownMenuItem(value: e, child: Text(e.label)),
                ],
                onChanged: (v) => state.updateExercise(ex, equipment: v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TrackingMode>(
                initialValue: ex.tracking,
                decoration: const InputDecoration(
                  labelText: 'What a set records',
                ),
                items: [
                  for (final t in TrackingMode.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => state.updateExercise(ex, tracking: v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<LoadSemantics>(
                initialValue: ex.loadSemantics,
                decoration: const InputDecoration(labelText: 'Load direction'),
                items: const [
                  DropdownMenuItem(
                    value: LoadSemantics.normal,
                    child: Text('Normal — higher is harder'),
                  ),
                  DropdownMenuItem(
                    value: LoadSemantics.assistanceInverted,
                    child: Text('Assistance — lower is harder'),
                  ),
                  DropdownMenuItem(
                    value: LoadSemantics.bodyweightOnly,
                    child: Text('Bodyweight'),
                  ),
                ],
                onChanged: (v) => state.updateExercise(ex, loadSemantics: v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<EffortClass>(
                initialValue: ex.effortClass,
                decoration: InputDecoration(
                  labelText: 'Rest bucket',
                  helperText:
                      'Default rest ${fmt.clock(Duration(seconds: ex.effortClass.restSeconds))}',
                ),
                items: [
                  for (final c in EffortClass.values)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (v) => state.updateExercise(ex, effortClass: v),
              ),
              const SizedBox(height: 20),
              Text(
                'LOAD DETAILS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Logged number is per side'),
                subtitle: const Text('Dumbbells, plate-loaded machines'),
                value: ex.loadIsPerSide,
                onChanged: (v) => state.updateExercise(ex, loadIsPerSide: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reps are per side'),
                subtitle: const Text('Pallof press, dead bug'),
                value: ex.repsPerSide,
                onChanged: (v) => state.updateExercise(ex, repsPerSide: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Stack labelled in pounds'),
                value: ex.stackUnit == StackUnit.lb,
                onChanged: (v) => state.updateExercise(
                  ex,
                  stackUnit: v ? StackUnit.lb : StackUnit.kg,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _base,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Base load (kg)',
                  helperText: 'Part of the weight you log, not extra on top',
                  suffixText: 'kg',
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  state.updateExercise(
                    ex,
                    baseLoadKg: parsed,
                    clearBaseLoad: v.trim().isEmpty,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _increment,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Smallest increment (kg)',
                  helperText: 'Used when suggesting the next load',
                  suffixText: 'kg',
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  state.updateExercise(
                    ex,
                    incrementKg: parsed,
                    clearIncrement: v.trim().isEmpty,
                  );
                },
              ),
              if (ex.equipment == Equipment.barbell) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _bar,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Bar weight',
                    suffixText: 'kg',
                  ),
                  onChanged: (v) => state.updateExercise(
                    ex,
                    barWeight: double.tryParse(v.replaceAll(',', '.')),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'STAND-INS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Offered first when you swap this exercise mid-session because '
                'the machine is taken. Pairing works both ways, so you only '
                'have to say it once.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in ex.alternativeIds)
                    InputChip(
                      label: Text(state.exerciseName(id)),
                      onDeleted: () => state.removeAlternative(ex, id),
                    ),
                  // Named by the other exercise rather than by this one. Shown
                  // because it is offered here too, but it is not this
                  // exercise's to delete — you would be editing the other one.
                  for (final other in linkedIn)
                    Chip(
                      avatar: Icon(Icons.link, size: 16, color: scheme.primary),
                      label: Text(other.name),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    onPressed: () async {
                      final id = await pickExercise(
                        context,
                        title: 'Stand-in for ${ex.name}',
                      );
                      if (id != null) state.addAlternative(ex, id);
                    },
                  ),
                ],
              ),
              if (linkedIn.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Linked chips were paired from the other exercise. Open that '
                  'one to undo it.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Notes'),
                onChanged: (v) => state.updateExercise(ex, notes: v),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                      ),
                      onPressed: () => _delete(context, state),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
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

  Future<void> _delete(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${widget.exercise.name}?'),
        content: const Text(
          'It is removed from the library and from every plan day. Past '
          'workouts keep their records.',
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
    if (ok != true || !context.mounted) return;
    state.deleteExercise(widget.exercise.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}
