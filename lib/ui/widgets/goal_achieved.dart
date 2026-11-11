import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import 'confetti.dart';

/// Shown when a goal is marked achieved.
///
/// A goal is the rarest thing in the app to finish — months of sessions, not
/// one — so it gets the loudest version of the celebration, and it says how
/// long it took and what actually moved on the way.
Future<void> showGoalAchieved(BuildContext context, {required Goal goal}) {
  final state = context.read<AppState>();
  if (state.settings.vibrate) _cheer();

  final readings = goal.markers
      .map(state.readMarker)
      .where((r) => r.hasData && r.improved)
      .toList();
  final days = state.now.difference(goal.startedAt).inDays;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Goal achieved',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondary) =>
        _GoalAchieved(goal: goal, readings: readings, days: days),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    ),
  );
}

Future<void> _cheer() async {
  try {
    if (!await Vibration.hasVibrator()) return;
    await Vibration.vibrate(pattern: [0, 70, 70, 70, 70, 70, 90, 260]);
  } catch (_) {
    // A phone that will not buzz has still finished the goal.
  }
}

class _GoalAchieved extends StatelessWidget {
  const _GoalAchieved({
    required this.goal,
    required this.readings,
    required this.days,
  });

  final Goal goal;
  final List<MarkerReading> readings;
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneMilestones = goal.milestones.where((m) => m.done).length;

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
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.55),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        size: 34,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Goal achieved',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (goal.target.isNotEmpty)
                      Text(
                        goal.target,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      days <= 0
                          ? '${goal.code} · set and reached the same day'
                          : '${goal.code} · $days days from the day you set it',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (doneMilestones > 0)
                      Text(
                        '$doneMilestones of ${goal.milestones.length} '
                        'milestones ticked off along the way',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    for (final reading in readings) ...[
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 18,
                            color: scheme.tertiary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reading.marker.label,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${_num(reading.marker.baseline)} → '
                                  '${_num(reading.current)}'
                                  '${reading.marker.unit.isEmpty ? '' : ' ${reading.marker.unit}'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
        const Positioned.fill(child: ConfettiBurst(pieces: 150)),
      ],
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
