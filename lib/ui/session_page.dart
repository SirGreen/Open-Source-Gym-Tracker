import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/app_state.dart';
import '../data/live_timer.dart';
import '../data/progression.dart';
import '../data/rest_timer.dart';
import '../models/models.dart';
import '../utils/formatting.dart' as fmt;
import 'widgets/exercise_picker.dart';
import 'widgets/finish_summary.dart';
import 'widgets/plate_sheet.dart';
import 'widgets/substitute_sheet.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({
    super.key,
    required this.sessionId,
    this.startEditing = false,
  });

  final String sessionId;

  /// A backfilled workout opens unlocked — there is nothing to read yet.
  final bool startEditing;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  /// Finished sessions open read-only; this unlocks them so a mistyped weight
  /// can be corrected instead of poisoning the charts and the progression rule.
  late bool _editing = widget.startEditing;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    WorkoutSession? found;
    for (final s in state.sessions) {
      if (s.id == widget.sessionId) found = s;
    }

    if (found == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This workout is no longer available.')),
      );
    }

    final session = found;
    final live = session.isActive;
    final editable = live || _editing;
    final day = state.plan.byId(session.planDayId);

    return PopScope(
      // Backing out of an edit applies the same rules as tapping Done, so an
      // abandoned backfill never leaves an empty workout in the history.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _editing) state.tidyFinishedSession(session);
      },
      child: _KeepScreenAwake(
        enabled: live,
        child: Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.title),
                _ElapsedText(session: session),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Session menu',
                icon: const Icon(Icons.more_vert),
                onPressed: () => _menu(context, state, session),
              ),
              if (live)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () => _finish(context, state, session),
                    child: const Text('Finish'),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _editing
                      ? FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: () =>
                              _stopEditing(context, state, session),
                          child: const Text('Done'),
                        )
                      : TextButton.icon(
                          onPressed: () => setState(() => _editing = true),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
            children: [
              if (live) _SessionHeader(session: session, day: day),
              if (_editing && !live) const _EditingBanner(),
              for (var i = 0; i < session.exercises.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseCard(
                    index: i,
                    session: session,
                    sessionExercise: session.exercises[i],
                    editable: editable,
                    live: live,
                  ),
                ),
              if (live) _LaggingSection(session: session),
              if (editable) ...[
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _addExercise(context, state, session),
                  icon: const Icon(Icons.add),
                  label: const Text('Add exercise'),
                ),
                const SizedBox(height: 20),
                _NotesField(
                  key: ValueKey('notes-${session.id}'),
                  session: session,
                ),
              ] else if (session.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(session.notes),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: live ? const _RestBar() : null,
        ),
      ),
    );
  }

  /// Leaving edit mode re-applies the finishing rules: sets you unticked did
  /// not happen, and a session emptied out is deleted.
  void _stopEditing(
    BuildContext context,
    AppState state,
    WorkoutSession session,
  ) {
    final survived = state.tidyFinishedSession(session);
    setState(() => _editing = false);
    if (!survived) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing left in it — workout removed')),
      );
    }
  }

  Future<void> _addExercise(
    BuildContext context,
    AppState state,
    WorkoutSession session,
  ) async {
    final id = await pickExercise(context);
    if (id == null || !context.mounted) return;
    state.addExerciseToSession(session, id);
  }

  Future<void> _menu(
    BuildContext context,
    AppState state,
    WorkoutSession session,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (session.isActive)
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add exercise'),
                onTap: () => Navigator.of(context).pop('add'),
              ),
            if (session.isActive && session.exercises.length > 1)
              ListTile(
                leading: const Icon(Icons.swap_vert),
                title: const Text('Lagging muscles first'),
                subtitle: Text(
                  state.coverageMeaningful
                      ? 'Most under-trained muscle first, core stays last'
                      : 'Needs about two weeks of logs to judge',
                ),
                enabled: state.coverageMeaningful,
                onTap: () => Navigator.of(context).pop('need'),
              ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename workout'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: const Icon(Icons.monitor_weight_outlined),
              title: const Text('Bodyweight for this session'),
              onTap: () => Navigator.of(context).pop('bodyweight'),
            ),
            if (session.isActive)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Discard workout',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.of(context).pop('discard'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'add':
        await _addExercise(context, state, session);
      case 'need':
        final before = state.orderByNeed(session);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                before == null
                    ? 'Already in order of need'
                    : 'Lagging muscles first',
              ),
              action: before == null
                  ? null
                  : SnackBarAction(
                      label: 'Undo',
                      onPressed: () => state.restoreOrder(session, before),
                    ),
            ),
          );
      case 'rename':
        final name = await promptText(context, 'Workout name', session.title);
        if (name != null) state.renameSession(session, name);
      case 'bodyweight':
        final v = await promptText(
          context,
          'Bodyweight (kg)',
          fmt.trimNum(state.bodyweightFor(session)),
          numeric: true,
        );
        final kg = double.tryParse((v ?? '').replaceAll(',', '.'));
        if (kg != null && kg > 0) state.setSessionBodyweight(session, kg);
      case 'discard':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Discard workout?'),
            content: const Text('Everything logged in this session is lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          state.discardSession(session);
          context.read<RestTimer>().stop();
          Navigator.of(context).pop();
        }
    }
  }

  Future<void> _finish(
    BuildContext context,
    AppState state,
    WorkoutSession session,
  ) async {
    final pending = session.totalSets - session.doneSets;
    final missingRpe = session.exercises
        .where((e) => e.doneCount > 0 && e.lastWorkingSet?.rpe == null)
        .length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finish workout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${session.doneSets} sets completed'),
            Text(
              '${fmt.compact(state.sessionVolume(session))} kg total volume',
            ),
            Text(
              '${fmt.durationShort(session.durationAt(DateTime.now()))} elapsed',
            ),
            if (pending > 0) ...[
              const SizedBox(height: 12),
              Text(
                '$pending unfinished ${pending == 1 ? 'set' : 'sets'} will be dropped.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (missingRpe > 0) ...[
              const SizedBox(height: 12),
              Text(
                '$missingRpe ${missingRpe == 1 ? 'exercise has' : 'exercises have'} '
                'no RPE on the last set — progression advice needs it.',
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final saved = state.finishSession(session);
    context.read<RestTimer>().stop();

    if (!saved) {
      Navigator.of(context).pop();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing was logged — workout discarded')),
      );
      return;
    }

    // Celebrated over the session that earned it, then out to Today. The
    // dropped sets have to be counted above: finishing is what removes them.
    await showFinishSummary(
      context,
      summary: state.summarise(session, droppedSets: pending),
    );
    if (context.mounted) Navigator.of(context).pop();
  }
}

/// Keeps the screen on while a workout is being logged — unlocking the phone
/// between every set is the fastest way to make an app useless in a gym.
class _KeepScreenAwake extends StatefulWidget {
  const _KeepScreenAwake({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_KeepScreenAwake> createState() => _KeepScreenAwakeState();
}

class _KeepScreenAwakeState extends State<_KeepScreenAwake> {
  @override
  void initState() {
    super.initState();
    _apply(widget.enabled);
  }

  @override
  void didUpdateWidget(covariant _KeepScreenAwake old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled) _apply(widget.enabled);
  }

  @override
  void dispose() {
    _apply(false);
    super.dispose();
  }

  Future<void> _apply(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (e) {
      debugPrint('Wakelock unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<String?> promptText(
  BuildContext context,
  String title,
  String initial, {
  bool numeric = false,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textCapitalization: numeric
            ? TextCapitalization.none
            : TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

/// The muscles the log says are falling behind that nothing on today's card
/// works, each one tap from having something added for it. Rebuilt on every
/// change, so adding an exercise takes its muscle off the list and the next
/// one moves up.
class _LaggingSection extends StatelessWidget {
  const _LaggingSection({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lagging = state.laggingMusclesFor(session);
    if (lagging.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surfaceContainerHigh,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, size: 18, color: scheme.tertiary),
                const SizedBox(width: 10),
                Text(
                  'LAGGING MUSCLES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Short of the ~10 weekly sets that build, and nothing today '
              'works them.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            for (final l in lagging)
              _LaggingRow(
                session: session,
                volume: l.volume,
                suggestion: l.suggestion,
              ),
          ],
        ),
      ),
    );
  }
}

class _LaggingRow extends StatelessWidget {
  const _LaggingRow({
    required this.session,
    required this.volume,
    required this.suggestion,
  });

  final WorkoutSession session;
  final MuscleVolume volume;
  final ExerciseDef suggestion;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final muscle = volume.muscle.label;
    final color = volume.verdict == VolumeVerdict.maintaining
        ? scheme.tertiary
        : scheme.error;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  muscle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${fmt.trimNum(volume.weeklySets)}/wk',
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          Text(
            volume.missingFromPlan
                ? '${volume.verdict.meaning} · nothing in the plan trains it'
                : volume.verdict.meaning,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: () =>
                    state.addExerciseToSession(session, suggestion.id),
                icon: const Icon(Icons.add, size: 18),
                label: Text(suggestion.name),
              ),
              TextButton(
                onPressed: () async {
                  final id = await pickExercise(
                    context,
                    title: 'Add for $muscle',
                    query: muscle,
                  );
                  if (id != null) state.addExerciseToSession(session, id);
                },
                child: const Text('Other…'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session, required this.day});

  final WorkoutSession session;
  final PlanDay? day;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final warmup = day?.warmup ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (warmup.isNotEmpty)
            Card(
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.local_fire_department_outlined,
                      size: 18,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WARM-UP',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(warmup, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: const Icon(Icons.monitor_weight_outlined, size: 17),
              label: Text(
                'Bodyweight ${fmt.trimNum(state.bodyweightFor(session))} kg',
              ),
              onPressed: () async {
                final v = await promptText(
                  context,
                  'Bodyweight (kg)',
                  fmt.trimNum(state.bodyweightFor(session)),
                  numeric: true,
                );
                final kg = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (kg != null && kg > 0) {
                  state.setSessionBodyweight(session, kg);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ElapsedText extends StatefulWidget {
  const _ElapsedText({required this.session});

  final WorkoutSession session;

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.session.isActive) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final d = s.durationAt(DateTime.now());
    // A backfilled workout has no elapsed time, so do not print "0s" at it.
    final logged = d.inSeconds > 0
        ? '${fmt.dayMonth(s.start)} · ${fmt.durationShort(d)}'
        : fmt.dayMonth(s.start);

    return Text(
      s.isActive
          ? '${fmt.clock(d)} · ${s.doneSets}/${s.totalSets} sets'
          : logged,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.index,
    required this.session,
    required this.sessionExercise,
    required this.editable,
    required this.live,
  });

  final int index;
  final WorkoutSession session;
  final SessionExercise sessionExercise;

  /// Fields accept input — true for a live session or one being edited.
  final bool editable;

  /// The workout is happening now. Rest timers, progression advice and the
  /// auto-step banner are meaningless when revisiting a past session.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final def = state.exerciseById(sessionExercise.exerciseId);
    final previous = state.lastPerformance(
      sessionExercise.exerciseId,
      excludeSessionId: session.id,
    );
    final advice = live
        ? state.adviceFor(
            sessionExercise.exerciseId,
            sessionExercise.repMax,
            plannedWeight: sessionExercise.targetWeight,
            excludeSessionId: session.id,
          )
        : null;
    final targetUnit = def.tracking == TrackingMode.duration ? 's' : '';
    final record = state.personalRecordIn(session, sessionExercise);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sessionExercise.complete
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: sessionExercise.complete
                      ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        def.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sessionExercise.substitutedForId != null)
                        Text(
                          'instead of '
                          '${state.exerciseName(sessionExercise.substitutedForId!)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: scheme.tertiary,
                          ),
                        ),
                      Text(
                        '${sessionExercise.sets.length} × '
                        '${sessionExercise.repRange}$targetUnit'
                        '${def.repsPerSide ? '/side' : ''}'
                        '${sessionExercise.restSeconds > 0 ? ' · rest ${fmt.clock(Duration(seconds: sessionExercise.restSeconds))}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (def.equipment.usesPlates)
                  IconButton(
                    tooltip: 'Plate calculator',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.calculate_outlined, size: 20),
                    onPressed: () => showPlateSheet(
                      context,
                      exercise: def,
                      weight: sessionExercise.sets.isEmpty
                          ? 60
                          : sessionExercise.sets
                                .map((s) => s.weight)
                                .reduce((a, b) => a > b ? a : b),
                    ),
                  ),
                if (editable)
                  IconButton(
                    tooltip: 'Exercise options',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onPressed: () => _exerciseMenu(context, state, def),
                  ),
              ],
            ),
            if (sessionExercise.autoProgressed && live) ...[
              const SizedBox(height: 10),
              _AutoStepBanner(sessionExercise: sessionExercise, def: def),
            ] else if (advice != null) ...[
              const SizedBox(height: 10),
              _AdviceBanner(
                advice: advice,
                onSetIncrement:
                    editable && advice.kind == AdviceKind.needsIncrement
                    ? () => _editIncrement(context, state, def)
                    : null,
              ),
            ],
            if (sessionExercise.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 2, right: 6),
                child: Text(
                  sessionExercise.notes,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            _HeaderRow(def: def),
            const SizedBox(height: 2),
            for (var i = 0; i < sessionExercise.sets.length; i++)
              _SetRow(
                key: ValueKey(sessionExercise.sets[i].id),
                number: i + 1,
                def: def,
                set: sessionExercise.sets[i],
                previous: previous != null && i < previous.sets.length
                    ? previous.sets[i]
                    : null,
                sessionExercise: sessionExercise,
                editable: editable,
                live: live,
                isRecord: record?.set.id == sessionExercise.sets[i].id,
              ),
            if (record != null) _RecordBanner(def: def, record: record),
            _LoadHint(
              session: session,
              def: def,
              sessionExercise: sessionExercise,
            ),
            if (editable)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 6),
                child: Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () => state.addSet(sessionExercise),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add set'),
                    ),
                    const Spacer(),
                    if (sessionExercise.sets.any((s) => !s.done))
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: () => _tickAll(context, state, previous),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: Text(
                          sessionExercise.doneCount == 0
                              ? 'Tick all'
                              : 'Tick rest',
                        ),
                      ),
                  ],
                ),
              ),
            if (sessionExercise.doneCount > 0)
              _RpeRow(sessionExercise: sessionExercise, editable: editable),
          ],
        ),
      ),
    );
  }

  /// One tap for an exercise that went entirely to plan, with an undo — a
  /// mis-tap here would otherwise cost four taps to unpick.
  void _tickAll(
    BuildContext context,
    AppState state,
    SessionExercise? previous,
  ) {
    final ticked = state.completeRemainingSets(
      sessionExercise,
      previous: previous,
    );
    if (ticked.isEmpty) return;

    FocusScope.of(context).unfocus();
    if (live) {
      HapticFeedback.selectionClick();
      final rest = context.read<RestTimer>();
      rest.vibrateEnabled = state.settings.vibrate;
      if (state.settings.autoRest && sessionExercise.restSeconds > 0) {
        rest.label = state.exerciseName(sessionExercise.exerciseId);
        rest.start(sessionExercise.restSeconds);
      }
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${ticked.length} sets ticked'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              state.untickSets(ticked);
              if (live) context.read<RestTimer>().stop();
            },
          ),
        ),
      );
  }

  /// Builds the ramp and puts it in, telling you what it worked out and how
  /// to take it back. A warm-up you did not want is one tap to undo.
  void _addWarmup(BuildContext context, AppState state, ExerciseDef def) {
    final messenger = ScaffoldMessenger.of(context);
    final ramp = state.warmupFor(sessionExercise);

    if (ramp.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            state.workingLoadOf(sessionExercise) <= 0
                ? 'Put a working weight in first — the ramp is worked out from it.'
                : 'Nothing to ramp: the working weight is already about as light '
                      'as this movement goes.',
          ),
        ),
      );
      return;
    }

    final added = state.addWarmupSets(sessionExercise, ramp);
    final summary = ramp
        .map((w) => '${fmt.trimNum(w.weight)}×${w.reps}')
        .join('  ');

    messenger.showSnackBar(
      SnackBar(
        content: Text('Warm-up: $summary'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => state.removeSets(sessionExercise, added),
        ),
      ),
    );
  }

  /// The step is saved on the exercise rather than on today's slot: it is a
  /// fact about the machine, so every routine that uses it picks it up.
  Future<void> _editIncrement(
    BuildContext context,
    AppState state,
    ExerciseDef def,
  ) async {
    final v = await promptText(
      context,
      'Smallest increment (kg)',
      def.incrementKg == null ? '' : fmt.trimNum(def.incrementKg!),
      numeric: true,
    );
    if (v == null) return;
    if (v.trim().isEmpty) {
      state.updateExercise(def, clearIncrement: true);
      return;
    }
    final step = double.tryParse(v.trim().replaceAll(',', '.'));
    if (step != null) state.updateExercise(def, incrementKg: step);
  }

  /// Saved on the exercise like the increment: it is the same EZ bar every day
  /// the curl comes round. The logged number already includes the bar, so
  /// this moves the plate maths and the warm-ups, not past sets.
  Future<void> _editBarWeight(
    BuildContext context,
    AppState state,
    ExerciseDef def,
  ) async {
    final v = await promptText(
      context,
      'Bar weight (kg)',
      fmt.trimNum(def.barKg),
      numeric: true,
    );
    final kg = double.tryParse(v?.trim().replaceAll(',', '.') ?? '');
    if (kg != null) state.updateExercise(def, barWeight: kg);
  }

  Future<void> _exerciseMenu(
    BuildContext context,
    AppState state,
    ExerciseDef def,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        // A fresh compound shows every option, which is taller than the
        // sheet's share of a phone screen.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Swap for something else'),
                subtitle: const Text('Machine taken, spot busy, niggle'),
                onTap: () => Navigator.of(context).pop('swap'),
              ),
              ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(
                  def.tracking == TrackingMode.duration
                      ? 'Edit target seconds'
                      : 'Edit target reps',
                ),
                onTap: () => Navigator.of(context).pop('reps'),
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Edit rest time'),
                onTap: () => Navigator.of(context).pop('rest'),
              ),
              if (def.tracking.hasLoad)
                ListTile(
                  leading: const Icon(Icons.straighten),
                  title: const Text('Edit increment'),
                  subtitle: Text(
                    def.incrementKg == null
                        ? 'Not set — the load cannot step up on its own'
                        : '${fmt.trimNum(def.incrementKg!)} kg a step · '
                              'saved to the exercise',
                  ),
                  onTap: () => Navigator.of(context).pop('increment'),
                ),
              if (def.equipment == Equipment.barbell)
                ListTile(
                  leading: const Icon(Icons.fitness_center),
                  title: const Text('Edit bar weight'),
                  subtitle: Text(
                    '${fmt.trimNum(def.barKg)} kg bar · saved to the exercise',
                  ),
                  onTap: () => Navigator.of(context).pop('bar'),
                ),
              if (sessionExercise.doneCount == 0 &&
                  session.exercises.length > 1) ...[
                ListTile(
                  leading: const Icon(Icons.vertical_align_top),
                  title: const Text('Do this one next'),
                  subtitle: const Text('The machine you wanted is taken'),
                  onTap: () => Navigator.of(context).pop('sooner'),
                ),
                ListTile(
                  leading: const Icon(Icons.vertical_align_bottom),
                  title: const Text('Leave this for later'),
                  onTap: () => Navigator.of(context).pop('later'),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: const Text('Exercise note'),
                onTap: () => Navigator.of(context).pop('note'),
              ),
              if (def.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                  child: Text(
                    def.notes,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (warmupWorthwhile(def) &&
                  !sessionExercise.sets.any((s) => s.warmup))
                ListTile(
                  leading: const Icon(Icons.local_fire_department_outlined),
                  title: const Text('Add warm-up sets'),
                  subtitle: const Text('Ramps up to today\'s working weight'),
                  onTap: () => Navigator.of(context).pop('warmup'),
                ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Remove from workout',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case 'swap':
        final id = await pickSubstitute(
          context,
          session: session,
          sessionExercise: sessionExercise,
        );
        if (id == null || !context.mounted) return;
        state.substituteExercise(session, sessionExercise, id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Swapped in ${state.exerciseName(id)}')),
        );
      case 'reps':
        final v = await promptText(
          context,
          'Target range (e.g. 8-12)',
          sessionExercise.repRange,
        );
        if (v != null) {
          final nums = RegExp(
            r'\d+',
          ).allMatches(v).map((m) => int.parse(m.group(0)!)).toList();
          if (nums.isNotEmpty) {
            state.updateSessionExercise(
              sessionExercise,
              repMin: nums.first,
              repMax: nums.length > 1 ? nums[1] : nums.first,
            );
          }
        }
      case 'rest':
        final v = await promptText(
          context,
          'Rest (seconds)',
          '${sessionExercise.restSeconds}',
          numeric: true,
        );
        final secs = int.tryParse(v?.trim() ?? '');
        if (secs != null) {
          state.updateSessionExercise(sessionExercise, restSeconds: secs);
        }
      case 'increment':
        await _editIncrement(context, state, def);
      case 'bar':
        await _editBarWeight(context, state, def);
      case 'sooner':
        state.doExerciseNext(session, sessionExercise);
      case 'later':
        state.doExerciseLater(session, sessionExercise);
      case 'warmup':
        _addWarmup(context, state, def);
      case 'note':
        final v = await promptText(context, 'Note', sessionExercise.notes);
        if (v != null) state.updateSessionExercise(sessionExercise, notes: v);
      case 'remove':
        state.removeExerciseFromSession(session, sessionExercise.id);
    }
  }
}

class _AdviceBanner extends StatelessWidget {
  const _AdviceBanner({required this.advice, this.onSetIncrement});

  final ProgressionAdvice advice;

  /// Offered when the advice is stuck on an unknown machine step, so it can
  /// be filled in right where the app asks for it.
  final VoidCallback? onSetIncrement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, IconData icon) = switch (advice.kind) {
      AdviceKind.increase => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.trending_up,
      ),
      AdviceKind.stale => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.hourglass_bottom,
      ),
      AdviceKind.reduce => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.trending_down,
      ),
      AdviceKind.confirming => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.timelapse,
      ),
      AdviceKind.needsIncrement => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.straighten,
      ),
      AdviceKind.needsRpe => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.help_outline,
      ),
      _ => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.info_outline,
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advice.message,
                  style: TextStyle(fontSize: 12.5, color: fg, height: 1.3),
                ),
                if (onSetIncrement != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onSetIncrement,
                    child: const Text('Set increment'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Column headings adapt to what the exercise actually records.
/// Shown when the app opened the exercise at a heavier load on its own,
/// so the jump is never a surprise mid-set.
class _AutoStepBanner extends StatelessWidget {
  const _AutoStepBanner({required this.sessionExercise, required this.def});

  final SessionExercise sessionExercise;
  final ExerciseDef def;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final from = sessionExercise.previousLoad;
    final to = sessionExercise.sets.isEmpty
        ? null
        : sessionExercise.sets.first.weight;
    final headline = def.inverted ? 'Assistance dropped' : 'Load stepped up';
    final jump = (from != null && to != null)
        ? ' ${fmt.trimNum(from)} → ${fmt.trimNum(to)} kg'
        : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 16, color: scheme.onPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$headline for you:$jump. Reps back to '
              '${sessionExercise.repMin} — change it if the gym disagrees.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.def});

  final ExerciseDef def;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        children: [
          const SizedBox(width: 30, child: _Head('SET')),
          const Expanded(flex: 3, child: _Head('PREVIOUS')),
          if (def.tracking.hasLoad)
            Expanded(
              flex: 3,
              child: _Head(
                def.inverted
                    ? 'ASSIST'
                    // Bodyweight is already counted: this is what you hold.
                    : def.loadSemantics == LoadSemantics.bodyweightOnly
                    ? (def.loadIsPerSide ? '+KG/SIDE' : '+KG')
                    : def.loadIsPerSide
                    ? 'KG/SIDE'
                    : 'KG',
              ),
            ),
          if (def.tracking.hasDuration)
            const Expanded(flex: 3, child: _Head('SECONDS')),
          if (def.tracking.hasReps)
            Expanded(
              flex: 3,
              child: _Head(def.repsPerSide ? 'REPS/SIDE' : 'REPS'),
            ),
          if (def.tracking.hasTempo)
            const Expanded(flex: 3, child: _Head('TEMPO s')),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.number,
    required this.def,
    required this.set,
    required this.previous,
    required this.sessionExercise,
    required this.editable,
    required this.live,
    required this.isRecord,
  });

  final int number;
  final ExerciseDef def;
  final SetEntry set;
  final SetEntry? previous;
  final SessionExercise sessionExercise;
  final bool editable;
  final bool live;
  final bool isRecord;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final _weight = TextEditingController(
    text: _fmtWeight(widget.set.weight),
  );
  late final _reps = TextEditingController(
    text: widget.set.reps == 0 ? '' : '${widget.set.reps}',
  );
  late final _duration = TextEditingController(
    text: (widget.set.durationSeconds ?? 0) == 0
        ? ''
        : '${widget.set.durationSeconds}',
  );
  late final _tempo = TextEditingController(
    text: (widget.set.tempoSeconds ?? 0) == 0
        ? ''
        : fmt.trimNum(widget.set.tempoSeconds!),
  );

  static String _fmtWeight(double w) => w == 0 ? '' : fmt.trimNum(w);

  /// Set while a hold is being timed. Kept as a start instant rather than a
  /// tick count so the reading stays true across rebuilds and throttling.
  DateTime? _holdStart;
  Timer? _holdTicker;
  bool _buzzedTarget = false;

  /// The store owns the clock, so the hold reads the same time as everything
  /// else — and a test can wind it forward.
  AppState? _holdClock;

  int get _held {
    final start = _holdStart;
    final clock = _holdClock;
    if (start == null || clock == null) return 0;
    final seconds = clock.now.difference(start).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  bool get _holding => _holdStart != null;

  @override
  void dispose() {
    _holdTicker?.cancel();
    _weight.dispose();
    _reps.dispose();
    _duration.dispose();
    _tempo.dispose();
    super.dispose();
  }

  /// Starts counting up. A plank is measured, not estimated, and typing a
  /// number afterwards is a guess dressed as a measurement.
  void _startHold(BuildContext context) {
    final rest = context.read<RestTimer>();
    // Starting the next hold ends the rest between sets by definition.
    if (rest.running) rest.stop();

    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final state = context.read<AppState>();
    setState(() {
      _holdClock = state;
      _holdStart = state.now;
      _buzzedTarget = false;
    });

    final name = state.exerciseName(widget.sessionExercise.exerciseId);
    _holdTicker?.cancel();
    _holdTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() {});
      final start = _holdStart;
      final target = widget.sessionExercise.repMin;
      if (start != null) {
        liveTimer.countUp(
          title: name,
          text: 'Set ${widget.number}',
          startedAt: start,
          elapsed: _held,
          target: target,
        );
      }
      if (!_buzzedTarget && target > 0 && _held >= target) {
        _buzzedTarget = true;
        rest.vibrateEnabled = state.settings.vibrate;
        rest.buzzTarget();
      }
    });
  }

  /// Stops the clock and writes what was actually held.
  void _stopHold(BuildContext context, AppState state) {
    final seconds = _held;
    liveTimer.hide();
    _holdTicker?.cancel();
    setState(() {
      _holdTicker = null;
      _holdStart = null;
      _holdClock = null;
    });
    if (seconds <= 0) return;

    state.updateSet(widget.set, durationSeconds: seconds);
    _duration.text = '$seconds';
    // Stopping the clock is finishing the set, so tick it and start the rest.
    if (!widget.set.done) _toggle(context, state);
  }

  void _syncFromSet() {
    final set = widget.set;
    _weight.text = _fmtWeight(set.weight);
    _reps.text = set.reps == 0 ? '' : '${set.reps}';
    _duration.text = (set.durationSeconds ?? 0) == 0
        ? ''
        : '${set.durationSeconds}';
    _tempo.text = (set.tempoSeconds ?? 0) == 0
        ? ''
        : fmt.trimNum(set.tempoSeconds!);
  }

  /// Values change from outside this row too — "Tick all" filling blanks, or
  /// undoing it. Adopt the model when it disagrees with the field, but never
  /// stamp over what is being typed right now.
  @override
  void didUpdateWidget(covariant _SetRow old) {
    super.didUpdateWidget(old);
    final set = widget.set;
    _adopt(
      _weight,
      _fmtWeight(set.weight),
      (text) => (double.tryParse(text) ?? 0) == set.weight,
    );
    _adopt(
      _reps,
      set.reps == 0 ? '' : '${set.reps}',
      (text) => (int.tryParse(text) ?? 0) == set.reps,
    );

    final seconds = set.durationSeconds ?? 0;
    _adopt(
      _duration,
      seconds == 0 ? '' : '$seconds',
      (text) => (int.tryParse(text) ?? 0) == seconds,
    );

    final tempo = set.tempoSeconds ?? 0;
    _adopt(
      _tempo,
      tempo == 0 ? '' : fmt.trimNum(tempo),
      (text) => (double.tryParse(text) ?? 0) == tempo,
    );
  }

  void _adopt(
    TextEditingController controller,
    String desired,
    bool Function(String) alreadyMatches,
  ) {
    if (controller.text == desired || alreadyMatches(controller.text)) return;
    controller.text = desired;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final def = widget.def;
    final set = widget.set;
    final prev = widget.previous;

    final row = Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: set.done
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: GestureDetector(
              onTap: widget.editable
                  ? () => state.updateSet(set, warmup: !set.warmup)
                  : null,
              child: Center(
                child: set.warmup
                    ? Icon(
                        Icons.whatshot_outlined,
                        size: 16,
                        color: scheme.tertiary,
                      )
                    : Text(
                        '${widget.number}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: (prev == null || !widget.editable)
                  ? null
                  : () {
                      state.updateSet(
                        set,
                        weight: prev.weight,
                        reps: prev.reps,
                        durationSeconds: prev.durationSeconds,
                        tempoSeconds: prev.tempoSeconds,
                      );
                      _syncFromSet();
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _previousLabel(def, prev),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          if (def.tracking.hasLoad)
            Expanded(
              flex: 3,
              child: _NumField(
                controller: _weight,
                enabled: widget.editable,
                decimal: true,
                hint: prev != null ? fmt.trimNum(prev.weight) : '0',
                onChanged: (v) =>
                    state.updateSet(set, weight: double.tryParse(v) ?? 0),
              ),
            ),
          if (def.tracking.hasDuration) ...[
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: _holding
                  ? Center(
                      child: Text(
                        '${_held}s',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: _buzzedTarget
                              ? scheme.primary
                              : scheme.onSurface,
                        ),
                      ),
                    )
                  : _NumField(
                      controller: _duration,
                      enabled: widget.editable,
                      decimal: false,
                      hint:
                          '${prev?.durationSeconds ?? widget.sessionExercise.repMin}',
                      onChanged: (v) => state.updateSet(
                        set,
                        durationSeconds: int.tryParse(v) ?? 0,
                      ),
                    ),
            ),
            if (widget.live)
              SizedBox(
                width: 40,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: _holding ? 'Stop the hold' : 'Time this hold',
                  icon: Icon(
                    _holding ? Icons.stop_circle : Icons.timer_outlined,
                    color: _holding ? scheme.error : scheme.onSurfaceVariant,
                  ),
                  onPressed: _holding
                      ? () => _stopHold(context, state)
                      : () => _startHold(context),
                ),
              ),
          ],
          if (def.tracking.hasReps) ...[
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: _NumField(
                controller: _reps,
                enabled: widget.editable,
                decimal: false,
                hint: prev != null ? '${prev.reps}' : '0',
                onChanged: (v) =>
                    state.updateSet(set, reps: int.tryParse(v) ?? 0),
              ),
            ),
          ],
          if (def.tracking.hasTempo) ...[
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: _NumField(
                controller: _tempo,
                enabled: widget.editable,
                decimal: true,
                hint: prev?.tempoSeconds != null
                    ? fmt.trimNum(prev!.tempoSeconds!)
                    : fmt.trimNum(defaultTempoSeconds),
                onChanged: (v) =>
                    state.updateSet(set, tempoSeconds: double.tryParse(v) ?? 0),
              ),
            ),
          ],
          SizedBox(
            width: 44,
            child: widget.isRecord
                ? Tooltip(
                    message: 'Personal best',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.emoji_events,
                        color: scheme.tertiary,
                        size: 22,
                      ),
                      onPressed: widget.editable
                          ? () => _toggle(context, state)
                          : null,
                    ),
                  )
                : IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      set.done
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: set.done
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    onPressed: widget.editable
                        ? () => _toggle(context, state)
                        : null,
                  ),
          ),
        ],
      ),
    );

    // While the clock runs the whole row stops it: aiming at a 40 px icon
    // from the floor, mid-plank, is not a fair ask.
    if (_holding) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _stopHold(context, state),
        child: row,
      );
    }

    if (!widget.editable) return row;

    final messenger = ScaffoldMessenger.of(context);
    return Dismissible(
      key: ValueKey('dismiss-${set.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        // Captured before the removal, so undo puts it back in place rather
        // than on the end.
        final index = widget.sessionExercise.sets.indexOf(set);
        state.removeSet(widget.sessionExercise, set.id);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Set ${widget.number} deleted'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () =>
                    state.insertSet(widget.sessionExercise, index, set),
              ),
            ),
          );
      },
      child: row,
    );
  }

  static String _previousLabel(ExerciseDef def, SetEntry? prev) {
    if (prev == null) return '—';
    return switch (def.tracking) {
      TrackingMode.weightReps => '${fmt.trimNum(prev.weight)}×${prev.reps}',
      TrackingMode.bodyweightReps => '${prev.reps}',
      TrackingMode.duration => '${prev.durationSeconds ?? 0}s',
      TrackingMode.tempoReps =>
        '${prev.reps}×${fmt.trimNum(prev.tempoSeconds ?? 0)}s',
    };
  }

  void _toggle(BuildContext context, AppState state) {
    final set = widget.set;
    final nowDone = !set.done;

    // A quick tap on an untouched set should still record something sensible.
    if (nowDone) {
      state.completeSet(widget.sessionExercise, set, previous: widget.previous);
      _syncFromSet();
    } else {
      state.updateSet(set, done: false);
    }
    FocusScope.of(context).unfocus();

    if (!widget.live) return;

    final rest = context.read<RestTimer>();
    rest.vibrateEnabled = state.settings.vibrate;
    if (nowDone) {
      HapticFeedback.selectionClick();
      if (state.settings.autoRest && widget.sessionExercise.restSeconds > 0) {
        rest.label = state.exerciseName(widget.sessionExercise.exerciseId);
        rest.start(widget.sessionExercise.restSeconds);
      }
    }
  }
}

/// Translates the logged number into what it is actually worth — net pull on
/// an assistance machine, total with the sled, pounds on a lb-labelled stack.
class _LoadHint extends StatelessWidget {
  const _LoadHint({
    required this.session,
    required this.def,
    required this.sessionExercise,
  });

  final WorkoutSession session;
  final ExerciseDef def;
  final SessionExercise sessionExercise;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final sets = sessionExercise.sets;
    if (sets.isEmpty) return const SizedBox.shrink();

    final ref = sets.firstWhere((s) => s.weight > 0, orElse: () => sets.first);
    if (ref.weight <= 0 && !def.tracking.hasLoad)
      return const SizedBox.shrink();

    final bw = state.bodyweightFor(session);
    final parts = <String>[];

    if (def.inverted && ref.weight > 0) {
      parts.add(
        'net pull ≈ ${fmt.trimNum(bw - ref.weight)} kg '
        '(${fmt.trimNum(bw)} − ${fmt.trimNum(ref.weight)})',
      );
    } else if (def.loadIsPerSide && ref.weight > 0) {
      parts.add('${fmt.trimNum(ref.weight * 2)} kg total');
    } else if (def.baseLoadKg != null && ref.weight > def.baseLoadKg!) {
      // The logged number is the whole thing, so what is worth spelling out is
      // the part you actually have to hang on the machine.
      parts.add(
        '${fmt.trimNum(ref.weight - def.baseLoadKg!)} kg of plates on '
        'the ${fmt.trimNum(def.baseLoadKg!)} kg base',
      );
    }

    if (state.settings.showLbHint &&
        def.stackUnit == StackUnit.lb &&
        ref.weight > 0) {
      parts.add('≈ ${kgToLb(ref.weight).round()} lb on the stack');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2, left: 32, right: 6),
      child: Text(
        parts.join(' · '),
        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// The difficulty rating on the last completed set — the field the whole
/// progression rule hangs on.
class _RpeRow extends StatelessWidget {
  const _RpeRow({required this.sessionExercise, required this.editable});

  final SessionExercise sessionExercise;
  final bool editable;

  static String _meaningOf(double? rpe) => switch (rpe?.round()) {
    6 => 'Could do 4+ more',
    7 => 'Could do 3 more',
    8 => '2-3 reps left',
    9 => '1 rep left — sweet spot',
    10 => 'Nothing left',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final current = sessionExercise.lastWorkingSet?.rpe;

    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LAST SET FELT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (current != null) ...[
                const SizedBox(width: 8),
                Text(
                  _meaningOf(current),
                  style: TextStyle(fontSize: 11, color: scheme.primary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final v in const [6.0, 7.0, 8.0, 9.0, 10.0])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _RpeChip(
                    value: v,
                    selected: current == v,
                    onTap: !editable
                        ? null
                        : () => state.setLastSetRpe(
                            sessionExercise,
                            current == v ? null : v,
                          ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RpeChip extends StatelessWidget {
  const _RpeChip({required this.value, required this.selected, this.onTap});

  final double value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 36,
          child: Center(
            child: Text(
              '${value.round()}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Makes it obvious a past workout is unlocked, and what unticking means.
class _EditingBanner extends StatelessWidget {
  const _EditingBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.edit_outlined,
              size: 17,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Editing a logged workout. Tick what you actually did — '
                'anything left unticked is dropped when you tap Done.',
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
    );
  }
}

/// Called out the moment it happens, rather than left to be discovered on the
/// Progress tab weeks later.
class _RecordBanner extends StatelessWidget {
  const _RecordBanner({required this.def, required this.record});

  final ExerciseDef def;
  final ({SetEntry set, double score, double? previousBest}) record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final previous = record.previousBest;

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 6),
      child: Row(
        children: [
          Icon(Icons.emoji_events, size: 15, color: scheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              previous == null
                  ? 'First time on the board: '
                        '${formatScore(def, record.score)}.'
                  : 'Personal best — ${fmt.trimNum(previous)} → '
                        '${formatScore(def, record.score)}.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.enabled,
    required this.decimal,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool decimal;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
        ),
      ],
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontWeight: FontWeight.w400,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      ),
      onChanged: (v) => onChanged(v.replaceAll(',', '.')),
    );
  }
}

class _NotesField extends StatefulWidget {
  const _NotesField({super.key, required this.session});

  final WorkoutSession session;

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final _controller = TextEditingController(text: widget.session.notes);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 2,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'Session notes — "back sore", "3 days off before this"…',
      ),
      onChanged: (v) =>
          context.read<AppState>().setSessionNotes(widget.session, v),
    );
  }
}

class _RestBar extends StatelessWidget {
  const _RestBar();

  @override
  Widget build(BuildContext context) {
    final rest = context.watch<RestTimer>();
    final scheme = Theme.of(context).colorScheme;

    if (!rest.running && !rest.justFinished) return const SizedBox.shrink();

    final finished = rest.justFinished;
    return Material(
      color: finished ? scheme.tertiaryContainer : scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!finished)
              LinearProgressIndicator(
                value: rest.progress,
                minHeight: 3,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Icon(
                    finished
                        ? Icons.notifications_active
                        : Icons.timer_outlined,
                    size: 20,
                    color: finished
                        ? scheme.onTertiaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    finished
                        ? 'Rest over'
                        : fmt.clock(Duration(seconds: rest.remaining)),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: finished ? scheme.onTertiaryContainer : null,
                    ),
                  ),
                  const Spacer(),
                  if (!finished) ...[
                    TextButton(
                      onPressed: () => rest.addSeconds(-15),
                      child: const Text('−15s'),
                    ),
                    TextButton(
                      onPressed: () => rest.addSeconds(15),
                      child: const Text('+15s'),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: rest.stop,
                    icon: const Icon(Icons.close),
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
