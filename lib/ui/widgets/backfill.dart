import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../models/models.dart';
import '../../utils/formatting.dart' as fmt;
import '../session_page.dart';

/// Logs a workout that happened on [date] but was never written down. Picks
/// the routine when the day is ambiguous, then opens the session unlocked so
/// the numbers can be filled in.
Future<void> backfillWorkout(
  BuildContext context,
  AppState state,
  DateTime date,
) async {
  final scheduled = state.plan.daysForWeekday(date.weekday);

  PlanDay? day;
  if (scheduled.length == 1) {
    day = scheduled.first;
  } else {
    final choice = await _pickRoutine(context, state, date, scheduled);
    if (choice == null || !context.mounted) return;
    day = choice.day;
  }

  final session = state.backfillSession(date, day: day);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SessionPage(sessionId: session.id, startEditing: true),
    ),
  );
}

/// Wrapped so "Freestyle" (a null day) is distinguishable from cancelling.
typedef _RoutineChoice = ({PlanDay? day});

Future<_RoutineChoice?> _pickRoutine(
  BuildContext context,
  AppState state,
  DateTime date,
  List<PlanDay> scheduled,
) {
  // A rest day has nothing scheduled, so offer the whole plan.
  final options = scheduled.isNotEmpty ? scheduled : state.plan.days;

  return showModalBottomSheet<_RoutineChoice>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'What did you train on ${fmt.dayMonth(date)}?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              scheduled.isEmpty
                  ? 'Nothing was scheduled that day, so pick any routine.'
                  : 'Both were on the card that day.',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          for (final option in options)
            ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: Text(option.name),
              subtitle: Text('${option.activeItems.length} exercises'),
              onTap: () => Navigator.of(context).pop((day: option)),
            ),
          ListTile(
            leading: const Icon(Icons.bolt_outlined),
            title: const Text('Something else'),
            subtitle: const Text('Start empty and add the exercises yourself'),
            onTap: () => Navigator.of(context).pop((day: null)),
          ),
        ],
      ),
    ),
  );
}
