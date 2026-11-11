part of 'app_state.dart';

/// Reading the log back: volume, records, trends and bodyweight.
///
/// All of it derived, none of it stored. Anything in here can be thrown away
/// and recomputed from the sessions, which is why fixing a rule fixes history
/// too rather than needing a migration.
extension StatsAndTrends on AppState {
  List<WorkoutSession> sessionsInRange(DateTime from, DateTime to) =>
      finishedSessions
          .where((s) => !s.start.isBefore(from) && s.start.isBefore(to))
          .toList();

  DateTime get startOfWeek {
    final today = dateOnly(now);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  List<WorkoutSession> get thisWeekSessions =>
      sessionsInRange(startOfWeek, startOfWeek.add(const Duration(days: 7)));

  double get thisWeekVolume =>
      thisWeekSessions.fold(0.0, (a, s) => a + sessionVolume(s));

  /// Consecutive weeks, ending with the current one, containing a workout.
  int get weekStreak {
    var streak = 0;
    var weekStart = startOfWeek;
    if (sessionsInRange(
      weekStart,
      weekStart.add(const Duration(days: 7)),
    ).isEmpty) {
      weekStart = weekStart.subtract(const Duration(days: 7));
    }
    while (streak <= 520) {
      if (sessionsInRange(
        weekStart,
        weekStart.add(const Duration(days: 7)),
      ).isEmpty) {
        break;
      }
      streak++;
      weekStart = weekStart.subtract(const Duration(days: 7));
    }
    return streak;
  }

  /// Oldest -> newest. Walks history backwards so sessions sharing a timestamp
  /// keep a stable order through the sort.
  List<ExercisePoint> pointsFor(String exerciseId) {
    final def = exerciseById(exerciseId);
    final points = <ExercisePoint>[];
    for (final s in finishedSessions.reversed) {
      final bw = bodyweightFor(s);
      for (final e in s.exercises) {
        if (e.exerciseId != exerciseId) continue;
        final working = e.workingSets;
        if (working.isEmpty) continue;

        SetEntry best = working.first;
        for (final set in working) {
          if (setScore(def, set, bw) > setScore(def, best, bw)) best = set;
        }
        points.add(
          ExercisePoint(
            date: s.start,
            score: setScore(def, best, bw),
            volume: exerciseVolume(s, e),
            topWeight: best.weight,
            topReps: best.reps,
            topDuration: best.durationSeconds ?? 0,
            topTempo: best.tempoSeconds ?? 0,
            rpe: e.lastWorkingSet?.rpe,
            sessionId: s.id,
          ),
        );
      }
    }
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  /// Best completed set ever recorded, by the exercise's own score.
  /// [excludeSessionId] leaves a session out, so a session cannot be measured
  /// against itself when checking for a new best.
  ExercisePoint? personalRecord(String exerciseId, {String? excludeSessionId}) {
    ExercisePoint? best;
    for (final p in pointsFor(exerciseId)) {
      if (p.sessionId == excludeSessionId) continue;
      if (best == null || p.score > best.score) best = p;
    }
    return best;
  }

  /// The set in this session that beats everything logged before it, if there
  /// is one, together with the mark it broke. Only the session's best set is
  /// returned — one badge per exercise, not one per set.
  ({SetEntry set, double score, double? previousBest})? personalRecordIn(
    WorkoutSession session,
    SessionExercise se,
  ) {
    final def = exerciseById(se.exerciseId);
    final bw = bodyweightFor(session);

    SetEntry? topSet;
    var topScore = 0.0;
    for (final set in se.sets) {
      if (!set.counts) continue;
      final score = setScore(def, set, bw);
      if (score > topScore) {
        topScore = score;
        topSet = set;
      }
    }
    if (topSet == null || topScore <= 0) return null;

    final previous = personalRecord(
      se.exerciseId,
      excludeSessionId: session.id,
    );
    if (previous != null && topScore <= previous.score) return null;

    return (set: topSet, score: topScore, previousBest: previous?.score);
  }

  /// Exercises that appear in finished history, most recently trained first.
  List<String> get trainedExerciseIds {
    final seen = <String>[];
    for (final s in finishedSessions) {
      for (final e in s.exercises) {
        if (!seen.contains(e.exerciseId)) seen.add(e.exerciseId);
      }
    }
    return seen;
  }

  /// The training one session amounts to: every set that counted, with the
  /// rest it was given. Not the wall clock — see [setEffortSeconds].
  Duration sessionEffort(WorkoutSession session) {
    var seconds = 0;
    for (final e in session.exercises) {
      final def = exerciseById(e.exerciseId);
      for (final set in e.sets) {
        if (!set.counts) continue;
        seconds += setEffortSeconds(def, set, e.restSeconds);
      }
    }
    return Duration(seconds: seconds);
  }

  /// Estimated kilocalories for a session, from its work and the bodyweight
  /// recorded against it. Zero when nothing was ticked off: an empty session
  /// burned nothing worth claiming.
  double sessionCalories(WorkoutSession session) => kcalForTraining(
    sessionEffort(session).inSeconds / 60,
    bodyweightFor(session),
  );

  List<({DateTime weekStart, double volume, int sessions, double kcal})>
  weeklyVolume(int weeks) {
    final out =
        <({DateTime weekStart, double volume, int sessions, double kcal})>[];
    for (var i = weeks - 1; i >= 0; i--) {
      final start = startOfWeek.subtract(Duration(days: 7 * i));
      final list = sessionsInRange(start, start.add(const Duration(days: 7)));
      out.add((
        weekStart: start,
        volume: list.fold(0.0, (a, s) => a + sessionVolume(s)),
        sessions: list.length,
        kcal: list.fold(0.0, (a, s) => a + sessionCalories(s)),
      ));
    }
    return out;
  }

  /// Every trained lift with the direction it is going, worst first.
  ///
  /// [days] bounds how far back a verdict looks: a lift you have not touched
  /// in months should not be called stuck on the strength of last spring.
  /// Lifts with too little history are kept rather than hidden, because
  /// "not enough sessions yet" is itself worth seeing.
  List<ExerciseTrend> exerciseTrends({int days = 120}) {
    final from = dateOnly(now).subtract(Duration(days: days));
    final out = <ExerciseTrend>[];

    for (final id in trainedExerciseIds) {
      final points = pointsFor(
        id,
      ).where((p) => !p.date.isBefore(from)).toList();
      if (points.isEmpty) continue;

      final def = exerciseById(id);
      final scores = [for (final p in points) p.score];
      final verdict = verdictForScores(scores);

      final best = scores.reduce((a, b) => a > b ? a : b);

      out.add(
        ExerciseTrend(
          def: def,
          verdict: verdict,
          sessions: points.length,
          sessionsSinceBest: scores.length - 1 - lastImprovementIndex(scores),
          best: best,
          latest: scores.last,
          lastTrained: points.last.date,
          // Only worth attaching where it adds something the verdict does not:
          // a stuck lift you could simply load heavier.
          note: verdict.needsAttention
              ? staleLoadFlag(def: def, history: historyOf(id))?.message
              : null,
        ),
      );
    }

    out.sort((a, b) {
      final byVerdict = a.verdict.rank.compareTo(b.verdict.rank);
      if (byVerdict != 0) return byVerdict;
      // Then whatever was trained most recently: the lift you are actually
      // doing something about is the one worth reading first.
      final at = a.lastTrained, bt = b.lastTrained;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });
    return out;
  }

  /// Hard sets and volume per muscle group over the last [days] days —
  /// catches imbalances like legs running far ahead of upper body.
  List<({MuscleGroup muscle, int sets, double volume})> muscleBreakdown(
    int days,
  ) {
    final from = dateOnly(now).subtract(Duration(days: days - 1));
    final sets = <MuscleGroup, int>{};
    final volume = <MuscleGroup, double>{};

    for (final s in sessionsInRange(from, now.add(const Duration(days: 1)))) {
      final bw = bodyweightFor(s);
      for (final e in s.exercises) {
        final def = exerciseById(e.exerciseId);
        for (final set in e.sets) {
          if (!set.counts) continue;
          sets[def.muscle] = (sets[def.muscle] ?? 0) + 1;
          volume[def.muscle] =
              (volume[def.muscle] ?? 0) + setVolume(def, set, bw);
        }
      }
    }

    final out = [
      for (final m in sets.keys)
        (muscle: m, sets: sets[m]!, volume: volume[m] ?? 0),
    ];
    out.sort((a, b) => b.sets.compareTo(a.sets));
    return out;
  }

  // --------------------------------------------------------- muscle coverage

  /// Weekly hard sets per muscle over the trailing [days], with synergists
  /// counted at a fraction of a set, judged against the volume landmarks.
  /// Ordered worst-served first, so the neglected muscles lead.
  ///
  /// The window is measured from when tracking began, not from the first
  /// session in it — a fortnight off is real neglect and should show as one,
  /// but a fortnight-old install should not be marked down for the weeks it
  /// was not running.
  List<MuscleVolume> muscleCoverage({int days = 28}) {
    final today = dateOnly(now);
    final from = today.subtract(Duration(days: days - 1));

    final direct = <MuscleGroup, double>{};
    final indirect = <MuscleGroup, double>{};
    final daysTouched = <MuscleGroup, Set<DateTime>>{};

    for (final s in sessionsInRange(from, today.add(const Duration(days: 1)))) {
      final day = dateOnly(s.start);
      for (final e in s.exercises) {
        final def = exerciseById(e.exerciseId);
        final hard = e.sets.where((set) => set.counts).length.toDouble();
        if (hard == 0) continue;

        direct[def.muscle] = (direct[def.muscle] ?? 0) + hard;
        (daysTouched[def.muscle] ??= <DateTime>{}).add(day);

        for (final m in def.secondaryMuscles) {
          indirect[m] =
              (indirect[m] ?? 0) + hard * VolumeLandmarks.synergistShare;
          (daysTouched[m] ??= <DateTime>{}).add(day);
        }
      }
    }

    final began = settings.trackingSince;
    final start = began != null && dateOnly(began).isAfter(from)
        ? dateOnly(began)
        : from;
    final weeks = ((today.difference(start).inDays + 1) / 7).clamp(
      1.0,
      days / 7,
    );

    final planned = plannedWeeklySets();
    final out = [
      for (final m in MuscleGroup.values)
        MuscleVolume(
          muscle: m,
          directSets: (direct[m] ?? 0) / weeks,
          indirectSets: (indirect[m] ?? 0) / weeks,
          sessionsPerWeek: (daysTouched[m]?.length ?? 0) / weeks,
          plannedDirectSets: planned[m] ?? 0,
        ),
    ];
    out.sort((a, b) {
      final bySets = a.weeklySets.compareTo(b.weeklySets);
      // Ties, usually a run of untrained muscles, read in body order rather
      // than shuffling between rebuilds.
      return bySets != 0 ? bySets : a.muscle.index.compareTo(b.muscle.index);
    });
    return out;
  }

  /// Weekly sets per muscle, for ranking work by need. Null while the log is
  /// too short to call anything neglected — below that, any order is a guess.
  Map<MuscleGroup, double>? weeklySetsByMuscle() {
    if (!coverageMeaningful) return null;
    return {for (final m in muscleCoverage()) m.muscle: m.weeklySets};
  }

  /// Direct sets a full week of the routine schedules per muscle. A routine
  /// on two weekdays counts twice; a choice day counts on both options, so
  /// this is what the plan offers rather than what one week can hold.
  Map<MuscleGroup, double> plannedWeeklySets() {
    final out = <MuscleGroup, double>{};
    for (final day in plan.days) {
      final times = day.weekdays.length;
      if (times == 0) continue;
      for (final item in day.activeItems) {
        final def = exerciseById(item.exerciseId);
        out[def.muscle] = (out[def.muscle] ?? 0) + item.sets * times;
      }
    }
    return out;
  }

  /// Days of log the coverage window actually rests on. Below a fortnight the
  /// weekly averages are too thin to read as neglect.
  int get coverageDays {
    final began = settings.trackingSince;
    if (began == null) return 0;
    return dateOnly(now).difference(dateOnly(began)).inDays + 1;
  }

  bool get coverageMeaningful =>
      finishedSessions.isNotEmpty && coverageDays >= 14;

  // -------------------------------------------------------------- bodyweight

  /// Oldest first, for charting.
  List<BodyweightEntry> get bodyweightSeries => bodyweights.reversed.toList();

  /// Rolling average over [days]. Weight swings a kilo or two day to day —
  /// more than months of real change — so a single reading is mostly noise.
  /// Falls back to the most recent entry when the window is empty.
  double? averageBodyweight({int days = 7}) {
    if (bodyweights.isEmpty) return null;
    final from = dateOnly(now).subtract(Duration(days: days - 1));
    final window = bodyweights.where((e) => !e.date.isBefore(from)).toList();
    if (window.isEmpty) return bodyweights.first.kg;
    return window.fold(0.0, (a, e) => a + e.kg) / window.length;
  }

  /// What the app should assume you weigh right now.
  double get currentBodyweight => averageBodyweight() ?? settings.bodyweightKg;

  BodyweightEntry logBodyweight(double kg, {DateTime? date, String note = ''}) {
    final day = dateOnly(date ?? now);
    for (final e in bodyweights) {
      if (e.date == day) {
        e.kg = kg;
        e.note = note;
        settings.bodyweightKg = currentBodyweight;
        _touch();
        return e;
      }
    }
    final entry = BodyweightEntry(date: day, kg: kg, note: note);
    bodyweights.add(entry);
    _sortBodyweights();
    settings.bodyweightKg = currentBodyweight;
    _touch();
    return entry;
  }

  void deleteBodyweight(String id) {
    bodyweights.removeWhere((e) => e.id == id);
    if (bodyweights.isNotEmpty) settings.bodyweightKg = currentBodyweight;
    _touch();
  }

  /// Puts a deleted weigh-in back, for undo. The working bodyweight follows
  /// it, since removing the latest entry moved it in the first place.
  void restoreBodyweight(BodyweightEntry entry) {
    if (bodyweights.any((e) => e.id == entry.id)) return;
    bodyweights.add(entry);
    _sortBodyweights();
    settings.bodyweightKg = currentBodyweight;
    _touch();
  }
}
