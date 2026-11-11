import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../data/progression.dart';
import '../models/models.dart';
import '../utils/formatting.dart' as fmt;

/// The numbers a routine will open at, before you walk in.
///
/// Every load here is produced by the same builder a real session uses, so it
/// is a rehearsal rather than an estimate — what it says is what you will find
/// on the card when you press Start.
void showDayPreview(BuildContext context, PlanDay day) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => DayPreviewPage(dayId: day.id)));
}

class DayPreviewPage extends StatelessWidget {
  const DayPreviewPage({super.key, required this.dayId});

  final String dayId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final day = state.plan.byId(dayId);

    if (day == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preview')),
        body: const Center(child: Text('That routine has been deleted.')),
      );
    }

    final planned = state.previewDay(day);
    final totalSets = planned.fold(0, (a, p) => a + p.opening.sets.length);
    final stepping = planned.where((p) => p.steppedUp).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day.name),
            Text(
              '$totalSets sets across ${planned.length} exercises',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (stepping > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Card(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        size: 20,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          stepping == 1
                              ? 'One lift goes up today.'
                              : '$stepping lifts go up today.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (planned.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nothing active on this routine yet.'),
              ),
            )
          else
            for (final entry in planned)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PreviewRow(entry: entry),
              ),
          const SizedBox(height: 8),
          Text(
            'Worked out from what you last lifted and the progression rule. '
            'Log something before you train and these move with it.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.entry});

  final PlannedExercise entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final se = entry.opening;
    final def = entry.def;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    def.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _opening(entry),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: entry.steppedUp ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${se.sets.length} × ${se.repRange}'
              '${def.tracking == TrackingMode.duration ? 's' : ''}'
              '${def.repsPerSide ? '/side' : ''}'
              ' · rest ${fmt.clock(Duration(seconds: se.restSeconds))}'
              '${_climbing(entry)}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (entry.steppedUp && se.previousLoad != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Up from ${fmt.trimNum(se.previousLoad!)} kg — reps '
                      'start back at ${se.repMin}.',
                      style: TextStyle(fontSize: 12, color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ] else if (entry.advice.isWarning ||
                entry.advice.kind == AdviceKind.needsRpe) ...[
              const SizedBox(height: 8),
              Text(
                entry.advice.message,
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A note when the opening number is under the routine's own floor.
  ///
  /// You step towards a range you cannot reach yet rather than jumping to its
  /// bottom, which is right but reads like a bug: a 25 s hang against a
  /// printed 30-60 s looks wrong until it says why.
  static String _climbing(PlannedExercise entry) {
    final se = entry.opening;
    final first = se.sets.isEmpty ? null : se.sets.first;
    if (first == null) return '';

    final opening = entry.def.tracking == TrackingMode.duration
        ? (first.durationSeconds ?? 0)
        : first.reps;
    if (opening <= 0 || opening >= se.repMin) return '';

    final unit = entry.def.tracking == TrackingMode.duration ? 's' : '';
    return ' · working up to ${se.repMin}$unit';
  }

  /// The opening numbers in whatever this movement is actually measured in.
  static String _opening(PlannedExercise entry) {
    final se = entry.opening;
    final first = se.sets.isEmpty ? null : se.sets.first;
    if (first == null) return '—';

    return switch (entry.def.tracking) {
      TrackingMode.duration => '${first.durationSeconds ?? 0}s',
      TrackingMode.bodyweightReps => '${first.reps} reps',
      TrackingMode.tempoReps =>
        '${first.reps} × '
            '${fmt.trimNum(first.tempoSeconds ?? defaultTempoSeconds)}s',
      TrackingMode.weightReps =>
        first.weight <= 0 ? 'find one' : '${fmt.trimNum(first.weight)} kg',
    };
  }
}
