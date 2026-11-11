import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../utils/formatting.dart' as fmt;
import 'exercise_picker.dart';

/// Offers stand-ins for an exercise whose machine is taken.
/// Resolves to the chosen exercise id, or null if dismissed.
Future<String?> pickSubstitute(
  BuildContext context, {
  required WorkoutSession session,
  required SessionExercise sessionExercise,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _SubstituteSheet(session: session, sessionExercise: sessionExercise),
  );
}

class _SubstituteSheet extends StatelessWidget {
  const _SubstituteSheet({
    required this.session,
    required this.sessionExercise,
  });

  final WorkoutSession session;
  final SessionExercise sessionExercise;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final origin = state.exerciseById(sessionExercise.exerciseId);
    final completed = sessionExercise.sets.where((s) => s.done).length;
    final remaining = sessionExercise.sets.length - completed;

    final options = state.substitutesFor(
      sessionExercise.exerciseId,
      inSession: session.exercises.map((e) => e.exerciseId).toSet(),
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Swap ${origin.name}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              completed == 0
                  ? 'Machine taken? Pick a stand-in — the plan is untouched, '
                        'only today changes.'
                  : '$completed logged ${completed == 1 ? 'set stays' : 'sets stay'} '
                        'on ${origin.name}. The stand-in picks up the remaining '
                        '$remaining.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: options.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Nothing in your library trains ${origin.muscle.label} '
                        'the same way. Browse everything below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final option = options[i];
                      final group = _groupOf(option, origin);
                      final showHeader =
                          i == 0 || _groupOf(options[i - 1], origin) != group;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showHeader)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                              child: Text(
                                group,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          _OptionTile(option: option, origin: origin),
                        ],
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: OutlinedButton.icon(
              onPressed: () async {
                final id = await pickExercise(context, title: 'Any exercise');
                if (id != null && context.mounted) {
                  Navigator.of(context).pop(id);
                }
              },
              icon: const Icon(Icons.search),
              label: const Text('Browse all exercises'),
            ),
          ),
        ],
      ),
    );
  }
}

String _groupOf(SubstituteOption option, ExerciseDef origin) =>
    option.alreadyInSession
    ? "ALREADY ON TODAY'S CARD"
    : option.curated
    ? 'YOUR STAND-INS'
    : 'ALSO TRAINS ${origin.muscle.label.toUpperCase()}';

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.origin});

  final SubstituteOption option;
  final ExerciseDef origin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = option.exercise;
    final last = option.lastPerformed;

    final history = last == null
        ? 'Never logged — today sets its baseline'
        : 'Last: ${_lastLabel(e, last)}';

    return ListTile(
      title: Text(e.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e.equipment.label),
          Text(
            history,
            style: TextStyle(
              fontSize: 12,
              color: last == null ? scheme.onSurfaceVariant : scheme.primary,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: option.alreadyInSession
          ? Icon(Icons.event_repeat, size: 18, color: scheme.tertiary)
          : e.equipment != origin.equipment
          ? Chip(
              label: const Text('different kit'),
              labelStyle: const TextStyle(fontSize: 10.5),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
            )
          : null,
      onTap: () => Navigator.of(context).pop(e.id),
    );
  }

  static String _lastLabel(ExerciseDef def, SessionExercise performed) {
    final best = performed.lastWorkingSet;
    if (best == null) return '—';
    return switch (def.tracking) {
      TrackingMode.weightReps =>
        '${fmt.trimNum(best.weight)} kg × ${best.reps}',
      TrackingMode.bodyweightReps => '${best.reps} reps',
      TrackingMode.duration => '${best.durationSeconds ?? 0} s',
      TrackingMode.tempoReps =>
        '${best.reps} × ${fmt.trimNum(best.tempoSeconds ?? 0)} s',
    };
  }
}
