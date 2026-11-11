part of 'app_state.dart';

/// Running a workout: opening one, changing what is in it, and logging sets.
///
/// The line these draw is between a plan and a record. A session starts as a
/// copy of the routine and stops being one the moment anything is ticked, so
/// nothing in here reaches back and edits the plan it came from.
extension SessionOperations on AppState {
  WorkoutSession? get activeSession {
    for (final s in sessions) {
      if (s.isActive) return s;
    }
    return null;
  }

  List<WorkoutSession> get finishedSessions =>
      sessions.where((s) => !s.isActive).toList();

  double bodyweightFor(WorkoutSession session) =>
      session.bodyweightKg ?? currentBodyweight;

  double setVolumeIn(
    WorkoutSession session,
    SessionExercise se,
    SetEntry set,
  ) => setVolume(exerciseById(se.exerciseId), set, bodyweightFor(session));

  double exerciseVolume(WorkoutSession session, SessionExercise se) {
    final def = exerciseById(se.exerciseId);
    final bw = bodyweightFor(session);
    return se.sets.fold(0.0, (a, s) => a + setVolume(def, s, bw));
  }

  double sessionVolume(WorkoutSession session) =>
      session.exercises.fold(0.0, (a, e) => a + exerciseVolume(session, e));

  /// Every finished performance of an exercise, newest first.
  /// [before] limits the lookup to sessions earlier than a date, so a workout
  /// being backfilled is prefilled from what came before it rather than from
  /// something logged after the day in question.
  List<SessionExercise> historyOf(
    String exerciseId, {
    String? excludeSessionId,
    DateTime? before,
  }) {
    final out = <SessionExercise>[];
    for (final s in sessions) {
      if (s.isActive || s.id == excludeSessionId) continue;
      if (before != null && !s.start.isBefore(before)) continue;
      for (final e in s.exercises) {
        if (e.exerciseId == exerciseId && e.doneCount > 0) out.add(e);
      }
    }
    return out;
  }

  /// The most recent finished performance, used to prefill a new session.
  SessionExercise? lastPerformance(
    String exerciseId, {
    String? excludeSessionId,
    DateTime? before,
  }) {
    final h = historyOf(
      exerciseId,
      excludeSessionId: excludeSessionId,
      before: before,
    );
    return h.isEmpty ? null : h.first;
  }

  ProgressionAdvice adviceFor(
    String exerciseId,
    int repMax, {
    double? plannedWeight,
    String? excludeSessionId,
  }) {
    final def = exerciseById(exerciseId);
    final history = historyOf(exerciseId, excludeSessionId: excludeSessionId);
    final stale = staleLoadFlag(def: def, history: history);
    final advice = adviseProgression(
      def: def,
      history: history,
      repMax: repMax,
      plannedWeight: plannedWeight,
      requiredSessions: settings.autoProgressSessions,
    );
    // A stale load is the more actionable message unless the rule has already
    // earned an increase.
    if (stale != null && !advice.earned) return stale;
    return advice;
  }

  /// What [day] would open at, worked out without starting anything.
  ///
  /// Nothing here is stored: the slots are built and thrown away, so this can
  /// be called for any routine on any day without leaving a session behind.
  List<PlannedExercise> previewDay(PlanDay day) {
    final out = <PlannedExercise>[];
    for (final item in day.activeItems) {
      out.add(
        PlannedExercise(
          def: exerciseById(item.exerciseId),
          opening: _buildSessionExercise(
            exerciseId: item.exerciseId,
            sets: item.sets,
            repMin: item.repMin,
            repMax: item.repMax,
            restSeconds: item.restSeconds,
            targetWeight: item.targetWeight,
            notes: item.notes,
          ),
          advice: adviceFor(
            item.exerciseId,
            item.repMax,
            plannedWeight: item.targetWeight,
          ),
        ),
      );
    }
    return out;
  }

  WorkoutSession startFromDay(PlanDay day) {
    final session = WorkoutSession(
      planDayId: day.id,
      title: day.name,
      start: now,
      bodyweightKg: currentBodyweight,
    );
    for (final item in day.activeItems) {
      session.exercises.add(
        _buildSessionExercise(
          exerciseId: item.exerciseId,
          sets: item.sets,
          repMin: item.repMin,
          repMax: item.repMax,
          restSeconds: item.restSeconds,
          targetWeight: item.targetWeight,
          notes: item.notes,
        ),
      );
    }
    sessions.insert(0, session);
    _touch();
    return session;
  }

  WorkoutSession startEmptySession() {
    final session = WorkoutSession(
      title: 'Freestyle',
      start: now,
      bodyweightKg: currentBodyweight,
    );
    sessions.insert(0, session);
    _touch();
    return session;
  }

  /// A workout that happened but was never written down. Created already
  /// finished and dated to that day, then opened for editing — it is history,
  /// not something in progress, so no rest timers and no "in progress" banner.
  ///
  /// Sets start unticked: you tick what you actually did. Prefilled numbers
  /// come from the last session *before* that date, and automatic progression
  /// is skipped — you already know what you lifted, so there is nothing to
  /// suggest.
  WorkoutSession backfillSession(DateTime date, {PlanDay? day}) {
    // Midday, so the session sorts sensibly within its own date.
    final when = dateOnly(date).add(const Duration(hours: 12));
    final session = WorkoutSession(
      planDayId: day?.id,
      title: day?.name ?? 'Freestyle',
      start: when,
      end: when,
      bodyweightKg: currentBodyweight,
    );

    for (final item in day?.activeItems ?? const <PlanItem>[]) {
      session.exercises.add(
        _buildSessionExercise(
          exerciseId: item.exerciseId,
          sets: item.sets,
          repMin: item.repMin,
          repMax: item.repMax,
          restSeconds: item.restSeconds,
          targetWeight: item.targetWeight,
          notes: item.notes,
          before: when,
          allowAutoProgress: false,
        ),
      );
    }

    sessions.insert(0, session);
    _sortSessions();
    _touch();
    return session;
  }

  SessionExercise _buildSessionExercise({
    required String exerciseId,
    required int sets,
    required int repMin,
    required int repMax,
    required int restSeconds,
    double? targetWeight,
    String notes = '',
    DateTime? before,
    bool allowAutoProgress = true,
  }) {
    final def = exerciseById(exerciseId);
    final last = lastPerformance(exerciseId, before: before);
    final se = SessionExercise(
      exerciseId: exerciseId,
      repMin: repMin,
      repMax: repMax,
      restSeconds: restSeconds,
      targetWeight: targetWeight,
      notes: notes,
    );

    // Close the double-progression loop: when the last sessions earned the
    // increase, open today at the new load with reps back at the floor rather
    // than making you type it. Only ever with a known machine step.
    double? steppedLoad;
    if (allowAutoProgress &&
        settings.autoProgress &&
        def.tracking == TrackingMode.weightReps) {
      final advice = adviceFor(exerciseId, repMax, plannedWeight: targetWeight);
      if (advice.kind == AdviceKind.increase && advice.suggestedLoad != null) {
        steppedLoad = advice.suggestedLoad;
        final worked = last?.workingSets ?? const <SetEntry>[];
        se.autoProgressed = true;
        se.previousLoad = worked.isEmpty ? null : worked.last.weight;
      }
    }

    for (var i = 0; i < sets; i++) {
      final prev = (last != null && i < last.sets.length) ? last.sets[i] : null;
      final timed = def.tracking == TrackingMode.duration;
      se.sets.add(
        SetEntry(
          weight: steppedLoad ?? prev?.weight ?? targetWeight ?? 0,
          // A heavier bar resets the range: reps start at the floor again.
          reps: timed
              ? 0
              : steppedLoad != null
              ? repMin
              : nextTarget(prev?.reps, repMin, repMax, repStep),
          durationSeconds: timed
              ? nextTarget(
                  prev?.durationSeconds,
                  repMin,
                  repMax,
                  durationStepSeconds,
                )
              : null,
          tempoSeconds: def.tracking == TrackingMode.tempoReps
              ? prev?.tempoSeconds
              : null,
        ),
      );
    }
    return se;
  }

  SessionExercise addExerciseToSession(
    WorkoutSession session,
    String exerciseId, {
    bool first = false,
  }) {
    final def = exerciseById(exerciseId);
    final isTimed = def.tracking == TrackingMode.duration;
    final se = _buildSessionExercise(
      exerciseId: exerciseId,
      sets: 3,
      repMin: isTimed ? 30 : 8,
      repMax: isTimed ? 45 : 12,
      restSeconds: def.effortClass.restSeconds,
    );
    if (first) {
      session.exercises.insert(0, se);
    } else {
      session.exercises.add(se);
    }
    _touch();
    return se;
  }

  /// Brings an exercise to the front of the work not yet started — for the
  /// machine that is free now, or the one you wanted that is taken.
  ///
  /// Anything already under way keeps its place. The order of what has
  /// happened is a record, not a preference, and shuffling a finished exercise
  /// down the card would make the session read as though it went differently.
  void doExerciseNext(WorkoutSession session, SessionExercise se) {
    final from = session.exercises.indexWhere((e) => e.id == se.id);
    if (from < 0) return;

    var to = 0;
    for (var i = 0; i < session.exercises.length; i++) {
      if (session.exercises[i].doneCount > 0) to = i + 1;
    }
    // Already at the head of the queue, or itself part of the work done.
    if (to >= from) return;

    session.exercises.insert(to, session.exercises.removeAt(from));
    _touch();
  }

  /// Sends it to the end, for the one being put off rather than picked up.
  void doExerciseLater(WorkoutSession session, SessionExercise se) {
    final from = session.exercises.indexWhere((e) => e.id == se.id);
    if (from < 0 || from == session.exercises.length - 1) return;
    session.exercises.add(session.exercises.removeAt(from));
    _touch();
  }

  // ------------------------------------------------------- training by need

  /// Puts the work not yet started in order of need: the exercise whose
  /// muscle is furthest short of its weekly sets goes first, while you are
  /// freshest for it. Equal need keeps the plan's order, so a heavy press
  /// still leads the isolation for the same muscle.
  ///
  /// Core work stays at the back whatever its count — a tired trunk is a poor
  /// brace for everything after it. Work already under way keeps its place,
  /// as with [doExerciseNext].
  ///
  /// Returns the order it replaced, for [restoreOrder]; null when there is
  /// too little log to judge need, or nothing moved.
  List<SessionExercise>? orderByNeed(WorkoutSession session) {
    final need = weeklySetsByMuscle();
    if (need == null) return null;

    var from = 0;
    for (var i = 0; i < session.exercises.length; i++) {
      if (session.exercises[i].doneCount > 0) from = i + 1;
    }
    final waiting = session.exercises.sublist(from);
    final position = {
      for (var i = 0; i < waiting.length; i++) waiting[i].id: i,
    };
    bool isCore(SessionExercise se) =>
        exerciseById(se.exerciseId).effortClass == EffortClass.core;
    double setsFor(SessionExercise se) =>
        need[exerciseById(se.exerciseId).muscle] ?? 0;

    final sorted = [...waiting]
      ..sort((a, b) {
        final core = (isCore(a) ? 1 : 0) - (isCore(b) ? 1 : 0);
        if (core != 0) return core;
        final byNeed = setsFor(a).compareTo(setsFor(b));
        if (byNeed != 0) return byNeed;
        return position[a.id]!.compareTo(position[b.id]!);
      });
    var moved = false;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].id != waiting[i].id) moved = true;
    }
    if (!moved) return null;

    final before = [...session.exercises];
    session.exercises.replaceRange(from, session.exercises.length, sorted);
    _touch();
    return before;
  }

  /// Undoes [orderByNeed]. Anything added since keeps its place at the end,
  /// and anything removed since stays removed.
  void restoreOrder(WorkoutSession session, List<SessionExercise> order) {
    final present = {for (final e in session.exercises) e.id};
    final known = {for (final e in order) e.id};
    session.exercises.replaceRange(0, session.exercises.length, [
      ...order.where((e) => present.contains(e.id)),
      ...session.exercises.where((e) => !known.contains(e.id)),
    ]);
    _touch();
  }

  /// Muscles short of the weekly sets that build that nothing in [session]
  /// works directly, most neglected first, each with the movement to add for
  /// it. Empty until the log is long enough to call anything neglected.
  List<({MuscleVolume volume, ExerciseDef suggestion})> laggingMusclesFor(
    WorkoutSession session, {
    int limit = 3,
  }) {
    if (!coverageMeaningful) return const [];
    final today = {
      for (final e in session.exercises) exerciseById(e.exerciseId).muscle,
    };

    final out = <({MuscleVolume volume, ExerciseDef suggestion})>[];
    for (final volume in muscleCoverage()) {
      if (out.length >= limit) break;
      if (!volume.needsAttention || today.contains(volume.muscle)) continue;
      final suggestion = suggestionFor(volume.muscle);
      if (suggestion != null) {
        out.add((volume: volume, suggestion: suggestion));
      }
    }
    return out;
  }

  /// The movement to reach for when [muscle] needs more work.
  ///
  /// Whatever you already train for it wins, most recent first: it is the
  /// one you know the setup and the numbers for. After that the plan's own
  /// choices, then the rest of the library — in both cases lightest to fit
  /// first, since this is work added to the end of another muscle's session:
  /// isolation before compounds, and a stack or cable before free weights.
  ExerciseDef? suggestionFor(MuscleGroup muscle) {
    final candidates = exercises.where((e) => e.muscle == muscle).toList();
    if (candidates.isEmpty) return null;

    for (final id in trainedExerciseIds) {
      for (final e in candidates) {
        if (e.id == id) return e;
      }
    }

    final planOrder = <String, int>{};
    for (final day in plan.days) {
      for (final item in day.activeItems) {
        planOrder.putIfAbsent(item.exerciseId, () => planOrder.length);
      }
    }
    int fit(ExerciseDef e) => switch (e.effortClass) {
      EffortClass.machineIsolation => 0,
      EffortClass.isolation || EffortClass.core => 1,
      EffortClass.moderateCompound => 2,
      EffortClass.heavyCompound => 3,
    };
    int kit(ExerciseDef e) => switch (e.equipment) {
      Equipment.machineStack || Equipment.cable => 0,
      Equipment.machinePlateLoaded || Equipment.dumbbell => 1,
      _ => 2,
    };

    candidates.sort((a, b) {
      final pa = planOrder[a.id], pb = planOrder[b.id];
      if ((pa == null) != (pb == null)) return pa == null ? 1 : -1;
      final byFit = fit(a).compareTo(fit(b));
      if (byFit != 0) return byFit;
      final byKit = kit(a).compareTo(kit(b));
      if (byKit != 0) return byKit;
      if (pa != null && pb != null) return pa.compareTo(pb);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return candidates.first;
  }

  void removeExerciseFromSession(
    WorkoutSession session,
    String sessionExerciseId,
  ) {
    session.exercises.removeWhere((e) => e.id == sessionExerciseId);
    _touch();
  }

  // ------------------------------------------------------------- substitution

  /// Everything that names [exerciseId] as one of its own stand-ins. Pairing
  /// two movements is a statement about both of them, so the link is stored
  /// once and read from either end.
  List<ExerciseDef> linkedFrom(String exerciseId) => exercises
      .where((e) => e.id != exerciseId && e.alternativeIds.contains(exerciseId))
      .toList();

  /// Stand-ins for [exerciseId]: hand-picked ones first, then anything that
  /// trains the same muscle. Different kit is ranked above more of the same,
  /// since the usual reason to swap is that a machine is occupied.
  List<SubstituteOption> substitutesFor(
    String exerciseId, {
    Set<String> inSession = const {},
  }) {
    final origin = exerciseById(exerciseId);
    final seen = {exerciseId};
    final options = <SubstituteOption>[];

    void offer(ExerciseDef e, {required bool curated}) {
      if (!seen.add(e.id)) return;
      options.add(
        SubstituteOption(
          exercise: e,
          curated: curated,
          alreadyInSession: inSession.contains(e.id),
          lastPerformed: lastPerformance(e.id),
        ),
      );
    }

    for (final id in origin.alternativeIds) {
      for (final e in exercises) {
        if (e.id == id) offer(e, curated: true);
      }
    }
    // Its own picks lead, then the movements that picked it. A swap is
    // symmetric in the gym — if the goblet squat stands in for the leg press,
    // the leg press stands in for the goblet squat — and this way a new
    // variation only has to name the old one once.
    for (final e in linkedFrom(exerciseId)) {
      offer(e, curated: true);
    }

    final sameMuscle =
        exercises
            .where((e) => e.muscle == origin.muscle && !seen.contains(e.id))
            .toList()
          ..sort((a, b) {
            final aSameKit = a.equipment == origin.equipment ? 1 : 0;
            final bSameKit = b.equipment == origin.equipment ? 1 : 0;
            if (aSameKit != bSameKit) return aSameKit - bSameKit;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    for (final e in sameMuscle) {
      offer(e, curated: false);
    }

    // Everything already on today's card sinks to the bottom rather than
    // vanishing. On a well-built day most of the same-muscle work is already
    // scheduled, and hiding it leaves the sheet almost empty.
    return [
      ...options.where((o) => !o.alreadyInSession),
      ...options.where((o) => o.alreadyInSession),
    ];
  }

  /// Swaps a session slot for another exercise. Sets already completed stay
  /// on the original — they happened — and the stand-in picks up the ones
  /// left. Loads never carry across: two machines labelled the same are not
  /// the same resistance, so the stand-in starts from its own history.
  SessionExercise substituteExercise(
    WorkoutSession session,
    SessionExercise original,
    String replacementId,
  ) {
    final index = session.exercises.indexWhere((e) => e.id == original.id);
    if (index < 0 || replacementId == original.exerciseId) return original;

    final completed = original.sets.where((s) => s.done).length;
    final remaining = original.sets.length - completed;

    final replacement = _buildSessionExercise(
      exerciseId: replacementId,
      sets: remaining > 0 ? remaining : original.sets.length,
      repMin: original.repMin,
      repMax: original.repMax,
      restSeconds: original.restSeconds,
      // The note belongs to the exercise, not the slot — carrying "duration
      // stuck at 2 s" onto an inverted row is worse than no note at all.
    );
    // Swapping twice still points back at what the plan actually asked for.
    replacement.substitutedForId =
        original.substitutedForId ?? original.exerciseId;

    if (completed == 0) {
      session.exercises[index] = replacement;
    } else {
      original.sets.removeWhere((s) => !s.done);
      session.exercises.insert(index + 1, replacement);
    }
    _touch();
    return replacement;
  }

  void addAlternative(ExerciseDef exercise, String alternativeId) {
    if (alternativeId == exercise.id ||
        exercise.alternativeIds.contains(alternativeId)) {
      return;
    }
    exercise.alternativeIds.add(alternativeId);
    _touch();
  }

  void removeAlternative(ExerciseDef exercise, String alternativeId) {
    exercise.alternativeIds.remove(alternativeId);
    _touch();
  }

  void addSet(SessionExercise se) {
    final last = se.sets.isNotEmpty ? se.sets.last : null;
    se.sets.add(
      last?.copyAsPending() ??
          SetEntry(weight: se.targetWeight ?? 0, reps: se.repMin),
    );
    _touch();
  }

  // ---------------------------------------------------------------- warm-ups

  /// The load the warm-up is climbing towards: the heaviest working set on the
  /// card, or the plan's target when nothing is filled in yet.
  double workingLoadOf(SessionExercise se) {
    var top = 0.0;
    for (final set in se.sets) {
      if (set.warmup) continue;
      if (set.weight > top) top = set.weight;
    }
    return top > 0 ? top : (se.targetWeight ?? 0);
  }

  /// The ramp this exercise would get, in its own logged units. Empty when a
  /// warm-up would not help or there is no working load to aim at yet.
  List<WarmupSet> warmupFor(SessionExercise se) {
    final def = exerciseById(se.exerciseId);
    if (!warmupWorthwhile(def)) return const [];

    final working = workingLoadOf(se);
    if (working <= 0) return const [];

    return warmupRamp(
      def: def,
      workingLoad: working,
      plates: settings.plates,
      bodyweightKg: currentBodyweight,
    );
  }

  /// Puts [ramp] in front of the working sets, flagged as warm-ups so they
  /// never reach the volume totals or the progression rule however they are
  /// logged. They start unticked like any other set: the ramp is what you are
  /// about to do, and one left untouched is dropped when the session ends.
  ///
  /// Returns what it added, so one undo takes the whole ramp back out.
  List<SetEntry> addWarmupSets(SessionExercise se, List<WarmupSet> ramp) {
    if (ramp.isEmpty) return const [];

    final added = [
      for (final step in ramp)
        SetEntry(weight: step.weight, reps: step.reps, warmup: true),
    ];
    // Ahead of the working sets: that is the order they are done in, and the
    // set numbering down the card should read the way the session does.
    se.sets.insertAll(0, added);
    _touch();
    return added;
  }

  /// Takes a set of entries back out, for undoing a ramp in one go.
  void removeSets(SessionExercise se, List<SetEntry> sets) {
    final ids = {for (final s in sets) s.id};
    se.sets.removeWhere((s) => ids.contains(s.id));
    _touch();
  }

  void removeSet(SessionExercise se, String setId) {
    se.sets.removeWhere((s) => s.id == setId);
    _touch();
  }

  /// Puts a swiped-away set back where it was. The entry itself is kept, so
  /// the weight, reps and RPE come back with it rather than being retyped.
  void insertSet(SessionExercise se, int index, SetEntry set) {
    if (se.sets.any((s) => s.id == set.id)) return;
    se.sets.insert(index.clamp(0, se.sets.length), set);
    _touch();
  }

  void updateSet(
    SetEntry set, {
    double? weight,
    int? reps,
    int? durationSeconds,
    double? tempoSeconds,
    double? rpe,
    bool clearRpe = false,
    bool? done,
    bool? warmup,
  }) {
    if (weight != null) set.weight = weight < 0 ? 0 : weight;
    if (reps != null) set.reps = reps < 0 ? 0 : reps;
    if (durationSeconds != null) {
      set.durationSeconds = durationSeconds < 0 ? 0 : durationSeconds;
    }
    if (tempoSeconds != null) {
      set.tempoSeconds = tempoSeconds < 0 ? 0 : tempoSeconds;
    }
    if (clearRpe) {
      set.rpe = null;
    } else if (rpe != null) {
      set.rpe = rpe;
    }
    if (done != null) set.done = done;
    if (warmup != null) set.warmup = warmup;

    // Typing a number is a keystroke; ticking a set is a decision.
    final boundary = done != null || warmup != null || rpe != null || clearRpe;
    _touch(eager: boundary);
  }

  /// Ticking off a set that was never typed into still records something
  /// sensible: whatever the row was showing as a placeholder. Without this a
  /// quick tap logs zeroes, and markers like the negatives' descent time
  /// never populate.
  void completeSet(SessionExercise se, SetEntry set, {SetEntry? previous}) {
    _fillBlanks(se, set, previous);
    set.done = true;
    _touch();
  }

  void _fillBlanks(SessionExercise se, SetEntry set, SetEntry? previous) {
    final def = exerciseById(se.exerciseId);
    if (def.tracking.hasReps && set.reps == 0) {
      set.reps = previous?.reps ?? se.repMin;
    }
    if (def.tracking.hasDuration && (set.durationSeconds ?? 0) == 0) {
      set.durationSeconds = previous?.durationSeconds ?? se.repMin;
    }
    if (def.tracking.hasLoad && set.weight == 0) {
      set.weight = previous?.weight ?? se.targetWeight ?? 0;
    }
    if (def.tracking.hasTempo && (set.tempoSeconds ?? 0) == 0) {
      set.tempoSeconds = previous?.tempoSeconds ?? defaultTempoSeconds;
    }
  }

  /// Ticks off every set not yet logged, filling blanks exactly as a single
  /// tap would — for when the whole exercise went to plan and tapping four
  /// checkmarks is just ceremony. Returns the sets it changed, so the action
  /// can be undone in one go.
  List<SetEntry> completeRemainingSets(
    SessionExercise se, {
    SessionExercise? previous,
  }) {
    final changed = <SetEntry>[];
    for (var i = 0; i < se.sets.length; i++) {
      final set = se.sets[i];
      if (set.done) continue;
      final prev = (previous != null && i < previous.sets.length)
          ? previous.sets[i]
          : null;
      _fillBlanks(se, set, prev);
      set.done = true;
      changed.add(set);
    }
    if (changed.isNotEmpty) _touch();
    return changed;
  }

  void untickSets(List<SetEntry> sets) {
    for (final set in sets) {
      set.done = false;
    }
    _touch();
  }

  /// RPE belongs to the last completed working set — that is the one the
  /// progression rule reads.
  void setLastSetRpe(SessionExercise se, double? rpe) {
    final target = se.lastWorkingSet;
    if (target == null) return;
    target.rpe = rpe;
    _touch();
  }

  void updateSessionExercise(
    SessionExercise se, {
    int? repMin,
    int? repMax,
    int? restSeconds,
    String? notes,
  }) {
    if (repMin != null) se.repMin = repMin.clamp(1, 600);
    if (repMax != null) se.repMax = repMax.clamp(1, 600);
    if (se.repMax < se.repMin) se.repMax = se.repMin;
    if (restSeconds != null) se.restSeconds = restSeconds.clamp(0, 900);
    if (notes != null) se.notes = notes;
    _touch();
  }

  void setSessionNotes(WorkoutSession session, String notes) {
    session.notes = notes;
    _touch(eager: false);
  }

  void setSessionBodyweight(WorkoutSession session, double? kg) {
    session.bodyweightKg = kg;
    // Weighing yourself during a workout is still a weigh-in.
    if (kg != null && session.isActive) {
      logBodyweight(kg, date: session.start);
    }
    _touch();
  }

  void renameSession(WorkoutSession session, String title) {
    if (title.trim().isEmpty) return;
    session.title = title.trim();
    _touch();
  }

  /// Ends the session, dropping sets that were never completed so history
  /// only contains work that actually happened. Returns false when nothing
  /// was logged, in which case the session is discarded instead.
  bool finishSession(WorkoutSession session) {
    if (session.doneSets == 0) {
      discardSession(session);
      return false;
    }
    for (final e in session.exercises) {
      e.sets.removeWhere((s) => !s.done);
    }
    session.exercises.removeWhere((e) => e.sets.isEmpty);
    session.end = now;
    _sortSessions();
    _touch();
    unawaited(_autoBackup());
    return true;
  }

  /// Reads back what just happened, for the screen shown after a workout.
  ///
  /// Call it after [finishSession], which is when the session holds only work
  /// that actually took place. [droppedSets] has to be counted before that,
  /// because finishing is what removes them.
  SessionSummary summarise(WorkoutSession session, {int droppedSets = 0}) {
    final records = <SessionRecord>[];
    final stepped = <ExerciseDef>[];

    for (final performed in session.exercises) {
      final def = exerciseById(performed.exerciseId);
      final best = personalRecordIn(session, performed);
      if (best != null) {
        records.add(
          SessionRecord(
            def: def,
            score: best.score,
            previousBest: best.previousBest,
          ),
        );
      }
      if (performed.autoProgressed) stepped.add(def);
    }

    return SessionSummary(
      title: session.title,
      sets: session.doneSets,
      volume: sessionVolume(session),
      duration: session.durationAt(now),
      records: records,
      steppedUp: stepped,
      droppedSets: droppedSets,
      weekStreak: weekStreak,
      calories: sessionCalories(session),
    );
  }

  /// Applies the finishing rules again after a past session was edited:
  /// sets that were unticked never happened, and an exercise or session with
  /// nothing left in it goes too. Returns false if the session was removed.
  bool tidyFinishedSession(WorkoutSession session) {
    if (session.isActive) return true;
    for (final e in session.exercises) {
      e.sets.removeWhere((s) => !s.done);
    }
    session.exercises.removeWhere((e) => e.sets.isEmpty);
    if (session.exercises.isEmpty) {
      sessions.removeWhere((s) => s.id == session.id);
      _touch();
      return false;
    }
    _touch();
    return true;
  }

  void discardSession(WorkoutSession session) {
    sessions.removeWhere((s) => s.id == session.id);
    _touch();
  }

  void deleteSession(String id) {
    sessions.removeWhere((s) => s.id == id);
    _touch();
  }

  /// Puts a deleted workout back, for undo.
  void restoreSession(WorkoutSession session) {
    if (sessions.any((s) => s.id == session.id)) return;
    sessions.add(session);
    _sortSessions();
    _touch();
  }
}
