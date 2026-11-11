import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';

/// Bottom-sheet movement picker with search and inline "create new".
/// Resolves to the chosen exercise id, or null if dismissed.
/// [query] opens it already searched, e.g. on a muscle's name.
Future<String?> pickExercise(
  BuildContext context, {
  String? title,
  String query = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _ExercisePickerSheet(title: title ?? 'Add exercise', query: query),
  );
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet({required this.title, this.query = ''});

  final String title;
  final String query;

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  late final _controller = TextEditingController(text: widget.query);
  late String _query = widget.query;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final q = _query.trim().toLowerCase();
    final matches = state.exercisesSorted
        .where(
          (e) =>
              q.isEmpty ||
              e.name.toLowerCase().contains(q) ||
              e.muscle.label.toLowerCase().contains(q),
        )
        .toList();

    final exactExists = state.exercises.any(
      (e) => e.name.toLowerCase() == q && q.isNotEmpty,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Search or type a new name',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            // A muscle's name is a filter, not the name of a new movement.
            if (q.isNotEmpty &&
                !exactExists &&
                !MuscleGroup.values.any((m) => m.label.toLowerCase() == q))
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text('Create "${_controller.text.trim()}"'),
                subtitle: const Text('Adds it to your exercise library'),
                onTap: () => _createNew(context, state),
              ),
            const Divider(),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('No matching exercises'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final e = matches[i];
                        final showHeader =
                            i == 0 || matches[i - 1].muscle != e.muscle;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showHeader)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  6,
                                ),
                                child: Text(
                                  e.muscle.label.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ListTile(
                              title: Text(e.name),
                              subtitle: Text(
                                '${e.equipment.label} · ${e.tracking.label}',
                              ),
                              onTap: () => Navigator.of(context).pop(e.id),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createNew(BuildContext context, AppState state) async {
    final name = _controller.text.trim();
    final details = await showDialog<(MuscleGroup, Equipment)>(
      context: context,
      builder: (_) => _NewExerciseDialog(name: name),
    );
    if (details == null || !context.mounted) return;
    final ex = state.addExercise(name, details.$1, details.$2);
    if (context.mounted) Navigator.of(context).pop(ex.id);
  }
}

class _NewExerciseDialog extends StatefulWidget {
  const _NewExerciseDialog({required this.name});

  final String name;

  @override
  State<_NewExerciseDialog> createState() => _NewExerciseDialogState();
}

class _NewExerciseDialogState extends State<_NewExerciseDialog> {
  MuscleGroup _muscle = MuscleGroup.back;
  Equipment _equipment = Equipment.machineStack;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<MuscleGroup>(
            initialValue: _muscle,
            decoration: const InputDecoration(labelText: 'Muscle group'),
            items: [
              for (final m in MuscleGroup.values)
                DropdownMenuItem(value: m, child: Text(m.label)),
            ],
            onChanged: (v) => setState(() => _muscle = v ?? _muscle),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Equipment>(
            initialValue: _equipment,
            decoration: const InputDecoration(labelText: 'Equipment'),
            items: [
              for (final e in Equipment.values)
                DropdownMenuItem(value: e, child: Text(e.label)),
            ],
            onChanged: (v) => setState(() => _equipment = v ?? _equipment),
          ),
          const SizedBox(height: 12),
          Text(
            'Tracking mode, rest bucket and load rules are set from these two, '
            'and can be fine-tuned in the exercise library.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          onPressed: () => Navigator.of(context).pop((_muscle, _equipment)),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
