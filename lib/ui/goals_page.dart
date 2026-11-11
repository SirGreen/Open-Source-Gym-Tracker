import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import 'goal_detail_page.dart';
import 'goal_edit_page.dart';

/// Cross-goal tensions from the plan document. Kept visible so a routine
/// change is judged against the primary goal rather than in isolation.
const _conflicts = [
  (
    'G1 + G7',
    'Losing weight helps pull-ups; aggressive dieting hurts strength',
  ),
  ('G1 + G5/G6', 'All want 2×/week — only ~4–5 training slots available'),
  ('G3 + G1', 'Arm work compromises pull days unless it sits at the end'),
  ('G5 + G2', 'Size-focused leg work may not prioritise abductors'),
];

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    final active = state.goals
        .where((g) => g.status == GoalStatus.active)
        .toList();
    final queued = state.goals
        .where((g) => g.status == GoalStatus.queued)
        .toList();
    final rest = state.goals
        .where(
          (g) => g.status != GoalStatus.active && g.status != GoalStatus.queued,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newGoal(context),
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
      body: state.goals.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No goals yet.',
                      style: TextStyle(
                        fontSize: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A goal with markers reads its own progress off the log.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => _newGoal(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add your first goal'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
              children: [
                if (active.isNotEmpty) ...[
                  _Label('IN PROGRESS', count: active.length),
                  for (final g in active) _GoalCard(goal: g, state: state),
                ],
                if (queued.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Label('QUEUED', count: queued.length),
                  for (final g in queued) _GoalCard(goal: g, state: state),
                ],
                if (rest.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _Label('ARCHIVE', count: rest.length),
                  for (final g in rest) _GoalCard(goal: g, state: state),
                ],
                const SizedBox(height: 76),
                _Label('KNOWN CONFLICTS'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in _conflicts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 74,
                                  child: Text(
                                    c.$1,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    c.$2,
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
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

Future<void> _newGoal(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => const GoalEditPage()));

class _Label extends StatelessWidget {
  const _Label(this.text, {this.count});

  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        count == null ? text : '$text · $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.state});

  final Goal goal;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final serving = state.plan.days
        .where((d) => d.goalIds.contains(goal.id))
        .map((d) => d.name)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GoalDetailPage(goalId: goal.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: goal.primary
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        goal.code,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: goal.primary
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        goal.title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (goal.primary)
                      Icon(Icons.star, size: 17, color: scheme.primary),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    goal.type.label,
                    if (goal.target.isNotEmpty) goal.target,
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (serving.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Trained on ${serving.join(', ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                if (goal.markers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.speed, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${goal.markers.length} tracked '
                        'marker${goal.markers.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: scheme.primary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
