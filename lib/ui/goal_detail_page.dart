import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../utils/formatting.dart' as fmt;
import 'goal_edit_page.dart';
import 'widgets/goal_achieved.dart';

/// Marks the goal, and celebrates only on the way *into* achieved.
///
/// Re-tapping a chip that is already selected must not set off the confetti
/// again — a celebration you can trigger on demand stops meaning anything.
void _setStatus(
  BuildContext context,
  AppState state,
  Goal goal,
  GoalStatus status,
) {
  final reached =
      status == GoalStatus.achieved && goal.status != GoalStatus.achieved;
  state.updateGoal(goal, status: status);
  if (reached) showGoalAchieved(context, goal: goal);
}

class GoalDetailPage extends StatelessWidget {
  const GoalDetailPage({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goal = state.goalById(goalId);
    final scheme = Theme.of(context).colorScheme;

    if (goal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This goal was deleted.')),
      );
    }

    final readings = goal.markers.map(state.readMarker).toList();
    final serving = state.plan.days
        .where((d) => d.goalIds.contains(goal.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(goal.code),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(context, goal.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            goal.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (goal.target.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                goal.target,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(goal.type.label),
                visualDensity: VisualDensity.compact,
              ),
              ...GoalStatus.values.map(
                (s) => ChoiceChip(
                  label: Text(s.label),
                  selected: goal.status == s,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => _setStatus(context, state, goal, s),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Primary goal'),
            subtitle: const Text('Routine changes are judged against this one'),
            value: goal.primary,
            onChanged: (v) => state.updateGoal(goal, primary: v),
          ),
          if (readings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionLabel('PROGRESS MARKERS'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Expanded(flex: 4, child: _Head('MARKER')),
                          const Expanded(flex: 2, child: _Head('BASE')),
                          const Expanded(flex: 2, child: _Head('NOW')),
                          const SizedBox(width: 28),
                        ],
                      ),
                    ),
                    for (final r in readings) _MarkerRow(reading: r),
                  ],
                ),
              ),
            ),
          ],
          if (goal.milestones.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('MILESTONES'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final m in goal.milestones)
                    CheckboxListTile(
                      value: m.done,
                      onChanged: (_) => state.toggleMilestone(goal, m),
                      title: Text(
                        m.label,
                        style: TextStyle(
                          decoration: m.done
                              ? TextDecoration.lineThrough
                              : null,
                          color: m.done ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                      subtitle: m.eta.isEmpty ? null : Text(m.eta),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                ],
              ),
            ),
          ],
          if (serving.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('TRAINED ON'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final d in serving)
                  Chip(
                    label: Text(d.name),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
          if (goal.notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('NOTES'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(goal.notes, style: const TextStyle(height: 1.45)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The editor reports a deletion, since this page would otherwise be left
/// showing a goal that no longer exists.
Future<void> _edit(BuildContext context, String goalId) async {
  final navigator = Navigator.of(context);
  final result = await navigator.push<String>(
    MaterialPageRoute(builder: (_) => GoalEditPage(goalId: goalId)),
  );
  if (result == 'deleted' && navigator.canPop()) navigator.pop();
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

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

class _Head extends StatelessWidget {
  const _Head(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({required this.reading});

  final MarkerReading reading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = reading.marker;
    final good = reading.improved;
    final flat = reading.stalled;
    final color = flat
        ? scheme.onSurfaceVariant
        : good
        ? scheme.primary
        : scheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  m.lowerIsBetter ? 'lower is better' : 'higher is better',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${fmt.trimNum(m.baseline)}${m.unit}',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${fmt.trimNum(reading.current)}${m.unit}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 28,
            child: Icon(
              flat
                  ? Icons.remove
                  : good
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              size: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
