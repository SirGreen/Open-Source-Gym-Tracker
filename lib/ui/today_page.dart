import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../utils/device.dart';
import '../utils/formatting.dart' as fmt;
import 'day_preview_page.dart';
import 'goal_detail_page.dart';
import 'session_page.dart';
import 'settings_page.dart';
import 'widgets/backfill.dart';
import 'widgets/missed_day_sheet.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final today = state.todaysDays;
    final active = state.activeSession;
    final goal = state.primaryGoal;
    final todayRecord = state.missedOn(now);
    final makeUps = state.outstandingMakeUps();
    final dueTest = state.dueGoalTest;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmt.weekdayLong[now.weekday - 1]),
                  Text(
                    fmt.dayMonth(now),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              sliver: SliverList.list(
                children: [
                  _WeekStrip(state: state),
                  const SizedBox(height: 20),
                  if (active != null)
                    _ResumeCard(session: active)
                  else if (todayRecord != null && !state.trainedOn(now))
                    _MarkedMissedCard(record: todayRecord, state: state)
                  else if (today.isEmpty)
                    const _RestDayCard()
                  else if (today.length == 1)
                    _PlannedDayCard(day: today.first, state: state)
                  else
                    _ChoiceDayCard(days: today, state: state),
                  if (makeUps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _CatchUpCard(makeUps: makeUps, state: state),
                  ],
                  if (dueTest != null) ...[
                    const SizedBox(height: 12),
                    _GoalTestCard(test: dueTest, state: state),
                  ],
                  if (state.exportOverdue) ...[
                    const SizedBox(height: 12),
                    _BackupNagCard(state: state),
                  ],
                  const SizedBox(height: 20),
                  _WeekStats(state: state),
                  if (goal != null) ...[
                    const SizedBox(height: 24),
                    Text('PRIMARY GOAL', style: labelStyle(context)),
                    const SizedBox(height: 10),
                    _GoalSnapshot(goal: goal, state: state),
                  ],
                  const SizedBox(height: 24),
                  Text('START ANOTHER DAY', style: labelStyle(context)),
                  const SizedBox(height: 10),
                  ...state.plan.days
                      .where((d) => !today.contains(d))
                      .map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DayRow(day: d, state: state),
                        ),
                      ),
                  if (state.plan.days.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No training days yet. Build your split in the Plan tab.',
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => startFreestyle(context, state),
                    icon: const Icon(Icons.bolt_outlined),
                    label: const Text('Freestyle workout'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle labelStyle(BuildContext context) => TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
  color: Theme.of(context).colorScheme.onSurfaceVariant,
);

Future<void> startDay(BuildContext context, AppState state, PlanDay day) async {
  if (state.activeSession != null) {
    final replace = await _confirmReplace(context);
    if (replace != true || !context.mounted) return;
    state.discardSession(state.activeSession!);
  }
  final session = state.startFromDay(day);
  if (!context.mounted) return;
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => SessionPage(sessionId: session.id)));
}

Future<void> startFreestyle(BuildContext context, AppState state) async {
  if (state.activeSession != null) {
    final replace = await _confirmReplace(context);
    if (replace != true || !context.mounted) return;
    state.discardSession(state.activeSession!);
  }
  final session = state.startEmptySession();
  if (!context.mounted) return;
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => SessionPage(sessionId: session.id)));
}

Future<bool?> _confirmReplace(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Discard current workout?'),
    content: const Text(
      'A workout is already in progress. Starting a new one throws it away.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Keep it'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text('Discard'),
      ),
    ],
  ),
);

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = fmt.dateOnly(now).subtract(Duration(days: now.weekday - 1));

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _WeekDayCell(
              date: monday.add(Duration(days: i)),
              label: fmt.weekdayNames[i],
              state: state,
            ),
          ),
      ],
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.date,
    required this.label,
    required this.state,
  });

  final DateTime date;
  final String label;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = state.statusOf(date);
    final isToday = fmt.sameDay(date, DateTime.now());
    final planned = state.plan.daysForWeekday(date.weekday);
    final onColor = isToday
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    final (IconData icon, Color tint) = switch (status) {
      DayStatus.trained => (
        Icons.check_circle,
        isToday ? scheme.onPrimaryContainer : scheme.primary,
      ),
      DayStatus.missed => (Icons.cancel_outlined, scheme.error),
      DayStatus.writtenOff => (
        Icons.do_not_disturb_on_outlined,
        scheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      DayStatus.restTaken => (Icons.bedtime_outlined, scheme.tertiary),
      DayStatus.today => (Icons.radio_button_unchecked, onColor),
      DayStatus.scheduled => (
        Icons.circle_outlined,
        onColor.withValues(alpha: 0.55),
      ),
      DayStatus.rest || DayStatus.untracked => (
        Icons.remove,
        scheme.onSurfaceVariant.withValues(alpha: 0.3),
      ),
    };

    final name = planned.isEmpty
        ? 'Rest'
        : planned.length > 1
        ? 'Pick'
        : _shortName(planned.first.name);
    final caption = switch (status) {
      DayStatus.missed => 'Missed',
      DayStatus.writtenOff => 'Off',
      DayStatus.restTaken => 'Rest',
      DayStatus.untracked => '—',
      _ => name,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: isToday ? scheme.primaryContainer : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => showMissedDaySheet(context, date),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: onColor,
                  ),
                ),
                const SizedBox(height: 5),
                Icon(icon, size: 17, color: tint),
                const SizedBox(height: 3),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: status == DayStatus.missed
                        ? scheme.error
                        : onColor.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Pull Day" -> "Pull", so seven of them fit across a phone.
  static String _shortName(String name) {
    final first = name.split(' ').first;
    return first.length > 5 ? first.substring(0, 5) : first;
  }
}

class _PlannedDayCard extends StatelessWidget {
  const _PlannedDayCard({required this.day, required this.state});

  final PlanDay day;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final trainedToday = state.trainedOn(now);
    // Training today is not the same as training *this*: a pull day done on a
    // push day leaves push undone, and the card is headlined "Push Day".
    final trained = state.routinesTrainedOn(now);
    final didThisDay = trained.contains(day.id);
    final instead = state.plan.days
        .where((d) => d.id != day.id && trained.contains(d.id))
        .map((d) => d.name)
        .toList();
    final items = day.activeItems;

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('ON THE PLAN TODAY', style: labelStyle(context)),
                const Spacer(),
                if (didThisDay)
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 15, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              day.name,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            if (day.focus.isNotEmpty)
              Text(day.focus, style: TextStyle(color: scheme.onSurfaceVariant)),
            // Say what did happen instead, rather than let the missing tick
            // stand as the only clue.
            if (trainedToday && !didThisDay)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  instead.isEmpty
                      ? 'Something else was logged today. '
                            'This one is still here if you want it.'
                      : '${instead.join(' and ')} done today instead. '
                            'This one is still here if you want it.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ...items
                .take(5)
                .map(
                  (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            state.exerciseName(i.exerciseId),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${i.sets} × ${i.repRange}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
            if (items.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+ ${items.length - 5} more',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: items.isEmpty
                    ? null
                    : () => startDay(context, state, day),
                icon: const Icon(Icons.play_arrow_rounded),
                // "Again" belongs to this day, not to the date: a first go at
                // push is not a repeat just because pull happened this morning.
                label: Text(didThisDay ? 'Train again' : 'Start workout'),
              ),
            ),
            if (items.isNotEmpty)
              Center(
                child: TextButton.icon(
                  onPressed: () => showDayPreview(context, day),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('See the numbers first'),
                ),
              ),
            if (!trainedToday)
              Center(
                child: _TakeRestButton(state: state, planDayId: day.id),
              ),
          ],
        ),
      ),
    );
  }
}

/// Day 6 of the rotation is "push or legs, whichever feels fresher".
class _ChoiceDayCard extends StatelessWidget {
  const _ChoiceDayCard({required this.days, required this.state});

  final List<PlanDay> days;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final trainedToday = state.trainedOn(now);
    // Only this day's own options can satisfy it, and only they belong in the
    // subtitle: a pull day trained on a push-or-legs day is neither half of
    // the choice, and reading it as one left the line naming nobody.
    final trained = state.routinesTrainedOn(now);
    final done = {
      for (final d in days)
        if (trained.contains(d.id)) d.id,
    };
    final left = days.where((d) => !done.contains(d.id)).toList();

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('YOUR CALL TODAY', style: labelStyle(context)),
                const Spacer(),
                // Either option satisfies the day; something else does not.
                if (done.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 15, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              days.map((d) => d.name.split(' ').first).join(' or '),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            Text(
              _subtitle(days, done, left, trainedToday),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            for (final d in days)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.surfaceContainerHighest,
                      foregroundColor: done.contains(d.id)
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => startDay(context, state, d),
                    icon: Icon(
                      done.contains(d.id)
                          ? Icons.check_circle
                          : Icons.play_arrow_rounded,
                      color: done.contains(d.id) ? scheme.primary : null,
                    ),
                    label: Text(
                      done.contains(d.id)
                          ? '${d.name}  ·  done today'
                          : '${d.name}  ·  '
                                '${d.activeItems.length} exercises',
                    ),
                  ),
                ),
              ),
            // Resting is a decision about a day you have not trained yet.
            if (!trainedToday) Center(child: _TakeRestButton(state: state)),
          ],
        ),
      ),
    );
  }

  /// The line under the headline, which has to say something different once
  /// half the choice has been made.
  static String _subtitle(
    List<PlanDay> days,
    Set<String> done,
    List<PlanDay> left,
    bool trainedToday,
  ) {
    if (done.isEmpty) {
      return trainedToday
          ? 'Trained today already. Either is still there if you want it.'
          : 'Whichever feels fresher.';
    }
    if (left.isEmpty) return 'Both done today.';
    final finished = days.where((d) => done.contains(d.id)).map((d) => d.name);
    return '${finished.join(' and ')} done. '
        '${left.first.name} is still there if you want it.';
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TODAY', style: labelStyle(context)),
            const SizedBox(height: 8),
            const Text(
              'Rest day',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scheduled rest — at least one every 3–4 sessions. Pick a day '
              'below if you want to train anyway.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IN PROGRESS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              session.title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: scheme.onPrimaryContainer,
              ),
            ),
            Text(
              'Started ${fmt.timeOfDay(session.start)} · '
              '${session.doneSets}/${session.totalSets} sets',
              style: TextStyle(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onPrimaryContainer,
                  foregroundColor: scheme.primaryContainer,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionPage(sessionId: session.id),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Resume workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSnapshot extends StatelessWidget {
  const _GoalSnapshot({required this.goal, required this.state});

  final Goal goal;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final readings = goal.markers.map(state.readMarker).toList();

    return Card(
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
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              if (goal.target.isNotEmpty)
                Text(
                  goal.target,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in readings.take(4)) _MarkerChip(reading: r),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkerChip extends StatelessWidget {
  const _MarkerChip({required this.reading});

  final MarkerReading reading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good = reading.improved;
    final flat = reading.stalled;
    final color = flat
        ? scheme.onSurfaceVariant
        : good
        ? scheme.primary
        : scheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reading.marker.label,
            style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${fmt.trimNum(reading.current)}${reading.marker.unit}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                flat
                    ? Icons.remove
                    : good
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
                size: 13,
                color: color,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sessions the week still owes you. Work that serves the primary goal is
/// listed first, because the plan gives pull two slots for that reason.
/// Every other G1 marker is a proxy. This is the goal itself, offered on the
/// interval the plan asks for rather than every session.
class _GoalTestCard extends StatelessWidget {
  const _GoalTestCard({required this.test, required this.state});

  final ({Goal goal, String exerciseId, int? daysSince}) test;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = state.exerciseName(test.exerciseId);

    return Card(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, size: 15, color: scheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Text(
                  'GOAL CHECK-IN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: scheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              test.daysSince == null
                  ? 'Never attempted. Everything else tracked for '
                        '${test.goal.code} is a proxy for this one.'
                  : 'Last attempt ${test.daysSince} days ago — the plan asks '
                        'for one every ${test.goal.testIntervalDays}.',
              style: TextStyle(
                color: scheme.onTertiaryContainer.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'One honest attempt, fresh. Log 0 if it does not move — that is '
              'still the measurement.',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onTertiaryContainer.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.onTertiaryContainer,
                  foregroundColor: scheme.tertiaryContainer,
                ),
                onPressed: () => _startTest(context, state, test.exerciseId),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  state.activeSession != null
                      ? "Add it to today's workout"
                      : 'Start with the test',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Puts the attempt at the front of a session — testing after an hour of
/// pulling measures fatigue, not strength.
Future<void> _startTest(
  BuildContext context,
  AppState state,
  String exerciseId,
) async {
  var session = state.activeSession;
  session ??= state.todaysDays.isNotEmpty
      ? state.startFromDay(state.todaysDays.first)
      : state.startEmptySession();

  final already = session.exercises.any((e) => e.exerciseId == exerciseId);
  if (!already) {
    state.addExerciseToSession(session, exerciseId, first: true);
  }

  if (!context.mounted) return;
  final id = session.id;
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => SessionPage(sessionId: id)));
}

/// Marks today as a deliberate rest day. Low-key on purpose: it sits under
/// the start button, not beside it.
class _TakeRestButton extends StatelessWidget {
  const _TakeRestButton({required this.state, this.planDayId});

  final AppState state;
  final String? planDayId;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onPressed: () => state.markRest(DateTime.now(), planDayId: planDayId),
      icon: const Icon(Icons.bedtime_outlined, size: 17),
      label: const Text('Taking a rest day'),
    );
  }
}

class _CatchUpCard extends StatelessWidget {
  const _CatchUpCard({required this.makeUps, required this.state});

  final List<MakeUp> makeUps;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final straight = state.consecutiveTrainingDays();

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat, size: 15, color: scheme.tertiary),
                const SizedBox(width: 8),
                Text('OWED THIS WEEK', style: labelStyle(context)),
              ],
            ),
            const SizedBox(height: 14),
            for (final makeUp in makeUps.take(3)) ...[
              _MakeUpRow(makeUp: makeUp, state: state),
              const SizedBox(height: 14),
            ],
            if (makeUps.length > 3)
              Text(
                '+ ${makeUps.length - 3} more',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            if (state.restIsDue)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.bedtime_outlined,
                      size: 16,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$straight days trained back to back. The plan asks '
                        'for a rest day every 3–4 sessions — catching up today '
                        'makes it ${straight + 1}.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MakeUpRow extends StatelessWidget {
  const _MakeUpRow({required this.makeUp, required this.state});

  final MakeUp makeUp;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reason = makeUp.record?.reason;
    final subtitle = [
      'Missed ${fmt.relativeDay(makeUp.date, DateTime.now()).toLowerCase()}',
      if (reason != null) reason.label,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                makeUp.options.map((d) => d.name).join(' or '),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (makeUp.servesPrimaryGoal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'primary goal',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final day in makeUp.options) ...[
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () => startDay(context, state, day),
                  child: Text(
                    makeUp.options.length == 1 ? 'Do it today' : day.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (day != makeUp.options.last) const SizedBox(width: 8),
            ],
          ],
        ),
        Row(
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () => backfillWorkout(context, state, makeUp.date),
              icon: const Icon(Icons.edit_calendar_outlined, size: 17),
              label: const Text('I already did it'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => state.markMissed(
                makeUp.date,
                planDayId: makeUp.record?.planDayId,
                reason: makeUp.record?.reason ?? MissReason.other,
                note: makeUp.record?.note ?? '',
                writtenOff: true,
              ),
              child: const Text('Let go'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Today was written off in advance — show that instead of the routine.
class _MarkedMissedCard extends StatelessWidget {
  const _MarkedMissedCard({required this.record, required this.state});

  final MissedDay record;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scheduled = state.plan.daysForWeekday(record.date.weekday);

    return Card(
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TODAY', style: labelStyle(context)),
            const SizedBox(height: 8),
            Text(
              record.isRest
                  ? 'Rest day'
                  : record.writtenOff
                  ? 'Written off'
                  : 'Marked as missed',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (scheduled.isNotEmpty)
                  scheduled.map((d) => d.name).join(' or '),
                if (!record.isRest) record.reason.label,
                if (record.note.isNotEmpty) record.note,
              ].join(' · '),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (record.isRest)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Taken on purpose — nothing owed. The plan asks for one '
                  'every 3–4 sessions.',
                  style: TextStyle(fontSize: 12.5, color: scheme.tertiary),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => state.clearMissed(record.date),
                    child: const Text('Undo'),
                  ),
                ),
                // A choice day gets one button per routine, so a rest day can
                // be reversed without undoing it first.
                for (final day in scheduled) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => startDay(context, state, day),
                      child: Text(
                        scheduled.length == 1 ? 'Train anyway' : day.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Every backup this app takes by itself lands on this phone, so losing the
/// phone loses the lot. This lives on Today rather than in Settings because
/// the warning is only worth anything where it will be read.
class _BackupNagCard extends StatelessWidget {
  const _BackupNagCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = state.daysSinceExport;

    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 18,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  days == null ? 'NEVER BACKED UP' : 'BACKUP IS OVERDUE',
                  style: labelStyle(
                    context,
                  ).copyWith(color: scheme.onErrorContainer),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              days == null
                  ? 'Nothing has ever left $thisDevice. The automatic '
                        'snapshots live here too, so they go with it.'
                  : 'Nothing has left $thisDevice in $days days. The automatic '
                        'snapshots live here too, so they go with it.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.onErrorContainer,
                    foregroundColor: scheme.errorContainer,
                  ),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Export now'),
                  onPressed: () => exportBackup(context, state),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStats extends StatelessWidget {
  const _WeekStats({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: '${state.thisWeekSessions.length}',
            label: 'workouts',
            sub: 'this week',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: fmt.compact(state.thisWeekVolume),
            label: 'kg',
            sub: 'volume',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            value: '${state.weekStreak}',
            label: state.weekStreak == 1 ? 'week' : 'weeks',
            sub: 'streak',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.sub,
  });

  final String value;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.state});

  final PlanDay day;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = day.activeItems.length;
    final days = day.weekdays.toList()..sort();

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: count == 0 ? null : () => startDay(context, state, day),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      count == 0
                          ? 'No exercises yet'
                          : '$count exercises'
                                '${days.isEmpty ? '' : ' · ${days.map(fmt.weekdayName).join(', ')}'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_arrow_rounded,
                color: count == 0
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.3)
                    : scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
