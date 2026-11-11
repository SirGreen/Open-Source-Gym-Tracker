import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../../data/app_state.dart';
import '../../data/progression.dart';
import '../../utils/formatting.dart' as fmt;
import 'confetti.dart';

/// Shown over the session once it is saved.
///
/// The point is that the confetti is earned rather than decorative: everything
/// on the card is a fact read back out of the workout that just happened, and
/// how much paper falls depends on which of those facts are true.
Future<void> showFinishSummary(
  BuildContext context, {
  required SessionSummary summary,
}) {
  final settings = context.read<AppState>().settings;
  if (settings.vibrate) _cheer(summary.fanfare);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Workout summary',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondary) =>
        _FinishSummary(summary: summary),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

/// A short flourish, not the rest timer's insistent one — this is a thing that
/// went well, not a thing that needs answering.
Future<void> _cheer(int fanfare) async {
  try {
    if (!await Vibration.hasVibrator()) return;
    await Vibration.vibrate(
      pattern: switch (fanfare) {
        3 => [0, 60, 70, 60, 70, 160],
        2 => [0, 60, 80, 120],
        _ => [0, 90],
      },
    );
  } catch (_) {
    // A phone that will not buzz has still finished the workout.
  }
}

class _FinishSummary extends StatelessWidget {
  const _FinishSummary({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Crest(fanfare: summary.fanfare),
                    const SizedBox(height: 18),
                    Text(
                      summary.headline,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    Text(
                      summary.title,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        _Stat(
                          value: '${summary.sets}',
                          label: summary.sets == 1 ? 'set' : 'sets',
                        ),
                        _Stat(
                          value: fmt.compact(summary.volume),
                          label: 'kg lifted',
                        ),
                        _Stat(
                          value: fmt.durationShort(summary.duration),
                          label: 'in the gym',
                        ),
                      ],
                    ),
                    if (summary.calories > 0) ...[
                      const SizedBox(height: 16),
                      _Line(
                        icon: Icons.local_fire_department_outlined,
                        color: scheme.tertiary,
                        title: '~${fmt.kcal(summary.calories)} kcal',
                        detail:
                            'Estimated from the work logged and your '
                            'bodyweight — not measured.',
                      ),
                    ],
                    for (final record in summary.records) ...[
                      const SizedBox(height: 16),
                      _Line(
                        icon: Icons.emoji_events,
                        color: scheme.primary,
                        title: record.def.name,
                        detail: record.previousBest == null
                            ? 'First time logged — '
                                  '${formatScore(record.def, record.score)}'
                            : '${formatScore(record.def, record.score)}, up '
                                  'from ${formatScore(record.def, record.previousBest!)}',
                      ),
                    ],
                    if (summary.steppedUp.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _Line(
                        icon: Icons.trending_up,
                        color: scheme.tertiary,
                        title: summary.steppedUp.length == 1
                            ? 'Load stepped up'
                            : '${summary.steppedUp.length} loads stepped up',
                        detail: summary.steppedUp.map((d) => d.name).join(', '),
                      ),
                    ],
                    if (summary.weekStreak > 1) ...[
                      const SizedBox(height: 16),
                      _Line(
                        icon: Icons.local_fire_department,
                        color: scheme.secondary,
                        title: '${summary.weekStreak} weeks running',
                        detail: 'Every one of them with a workout in it.',
                      ),
                    ],
                    if (!summary.cleanSweep) ...[
                      const SizedBox(height: 16),
                      Text(
                        '${summary.droppedSets} planned '
                        '${summary.droppedSets == 1 ? 'set was' : 'sets were'} '
                        'left undone — not counted.',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Over the card, so the paper falls in front of it.
        Positioned.fill(child: ConfettiBurst(pieces: 45 * summary.fanfare)),
      ],
    );
  }
}

/// The badge at the top. Grows a ring for a record so the three outcomes are
/// told apart at a glance rather than only by their wording.
class _Crest extends StatelessWidget {
  const _Crest({required this.fanfare});

  final int fanfare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colour = switch (fanfare) {
      3 => scheme.primary,
      2 => scheme.tertiary,
      _ => scheme.secondary,
    };

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: colour.withValues(alpha: 0.5), width: 2),
      ),
      child: Icon(
        switch (fanfare) {
          3 => Icons.workspace_premium,
          2 => Icons.task_alt,
          _ => Icons.check,
        },
        size: 32,
        color: colour,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                detail,
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
