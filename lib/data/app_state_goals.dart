part of 'app_state.dart';

/// Days that did not happen, and the goals they were meant to serve.
///
/// Adherence and intent: what the plan asked for against what took place, and
/// the longer arcs the plan exists to move.
extension AdherenceAndGoals on AppState {
  /// A session with nothing ticked off is not training — a backfill that was
  /// opened and abandoned must not count as a workout.
  bool trainedOn(DateTime date) =>
      finishedSessions.any((s) => sameDay(s.start, date) && s.doneSets > 0);

  /// Which routines were finished on [date], by plan day id. A choice day
  /// offers more than one, so knowing that something was trained is not the
  /// same as knowing which.
  Set<String> routinesTrainedOn(DateTime date) => {
    for (final s in finishedSessions)
      if (sameDay(s.start, date) && s.doneSets > 0 && s.planDayId != null)
        s.planDayId!,
  };

  MissedDay? missedOn(DateTime date) {
    final d = dateOnly(date);
    for (final m in missedDays) {
      if (m.date == d) return m;
    }
    return null;
  }

  /// A past scheduled day with nothing logged counts as missed even if it was
  /// never marked — the gap is the fact, the reason is optional detail.
  DayStatus statusOf(DateTime date) {
    final day = dateOnly(date);
    final today = dateOnly(now);

    if (trainedOn(day)) return DayStatus.trained;

    final record = missedOn(day);
    if (record != null) {
      if (record.isRest) return DayStatus.restTaken;
      return record.writtenOff ? DayStatus.writtenOff : DayStatus.missed;
    }

    final since = settings.trackingSince;
    if (since != null && day.isBefore(dateOnly(since))) {
      return DayStatus.untracked;
    }
    if (plan.daysForWeekday(day.weekday).isEmpty) return DayStatus.rest;
    if (day.isAfter(today)) return DayStatus.scheduled;
    if (day == today) return DayStatus.today;
    return DayStatus.missed;
  }

  bool servesPrimaryGoal(PlanDay day) {
    final goal = primaryGoal;
    return goal != null && day.goalIds.contains(goal.id);
  }

  /// Sessions this week that were scheduled, never trained, and not written
  /// off. Work that serves the primary goal comes first — the plan gives pull
  /// two slots a week precisely because it matters most — then oldest first.
  /// Today is never included: there is still time to train it.
  List<MakeUp> outstandingMakeUps() {
    final today = dateOnly(now);
    final out = <MakeUp>[];

    for (var i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      if (!date.isBefore(today)) break;
      if (trainedOn(date)) continue;

      final record = missedOn(date);
      if (record != null && (record.writtenOff || record.isRest)) continue;

      // Days before this install started tracking are nobody's debt, unless
      // they were explicitly marked.
      final since = settings.trackingSince;
      if (record == null && since != null && date.isBefore(dateOnly(since))) {
        continue;
      }

      final scheduled = plan.daysForWeekday(date.weekday);
      if (scheduled.isEmpty) continue;

      out.add(
        MakeUp(
          date: date,
          options: scheduled,
          record: record,
          servesPrimaryGoal: scheduled.any(servesPrimaryGoal),
        ),
      );
    }

    out.sort((a, b) {
      if (a.servesPrimaryGoal != b.servesPrimaryGoal) {
        return a.servesPrimaryGoal ? -1 : 1;
      }
      return a.date.compareTo(b.date);
    });
    return out;
  }

  /// Scheduled days coming up inside the next [days], each with the routines
  /// waiting on it. Today is included only while nothing has been logged yet.
  ///
  /// Days already trained, deliberately taken as rest, or written off are left
  /// out: a reminder for work that is already done or already forgiven is the
  /// fastest way to teach someone to swipe the notification away unread.
  List<UpcomingDay> upcomingTrainingDays({int days = 14}) {
    final today = dateOnly(now);
    final out = <UpcomingDay>[];

    for (var i = 0; i < days; i++) {
      final date = today.add(Duration(days: i));
      if (trainedOn(date)) continue;

      final record = missedOn(date);
      if (record != null && (record.writtenOff || record.isRest)) continue;

      final scheduled = plan.daysForWeekday(date.weekday);
      if (scheduled.isEmpty) continue;

      out.add(UpcomingDay(date: date, days: scheduled));
    }
    return out;
  }

  /// Days trained back to back, counting today. The plan asks for a rest day
  /// every 3-4 sessions, so this is what a catch-up has to be weighed against.
  int consecutiveTrainingDays() {
    var count = 0;
    var day = dateOnly(now);
    while (trainedOn(day) && count < 60) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  bool get restIsDue => consecutiveTrainingDays() >= 3;

  MissedDay markMissed(
    DateTime date, {
    String? planDayId,
    MissReason reason = MissReason.other,
    String note = '',
    bool writtenOff = false,
  }) {
    final existing = missedOn(date);
    if (existing != null) {
      existing.planDayId = planDayId ?? existing.planDayId;
      existing.reason = reason;
      existing.note = note;
      existing.writtenOff = writtenOff;
      _touch();
      return existing;
    }
    final record = MissedDay(
      date: date,
      planDayId: planDayId,
      reason: reason,
      note: note,
      writtenOff: writtenOff,
    );
    missedDays.add(record);
    _touch();
    return record;
  }

  /// Takes a scheduled day as rest on purpose. Written off by definition —
  /// the plan asks for a rest day every 3-4 sessions, so this is the plan
  /// being followed rather than a session going missing.
  MissedDay markRest(DateTime date, {String? planDayId, String note = ''}) =>
      markMissed(
        date,
        planDayId: planDayId,
        reason: MissReason.rest,
        note: note,
        writtenOff: true,
      );

  void clearMissed(DateTime date) {
    final d = dateOnly(date);
    missedDays.removeWhere((m) => m.date == d);
    _touch();
  }

  // -------------------------------------------------------------------- goals

  Goal? goalById(String id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// When an exercise was last performed, by session date.
  DateTime? lastPerformedAt(String exerciseId) {
    final points = pointsFor(exerciseId);
    return points.isEmpty ? null : points.last.date;
  }

  /// The primary goal's periodic attempt, when one is overdue. A goal like
  /// "first unassisted pull-up" is only truly measured by trying it — every
  /// other marker is a proxy — but attempting it every session is just
  /// fatigue, so it is offered on an interval.
  ({Goal goal, String exerciseId, int? daysSince})? get dueGoalTest {
    final goal = primaryGoal;
    final exerciseId = goal?.testExerciseId;
    if (goal == null || exerciseId == null) return null;

    final last = lastPerformedAt(exerciseId);
    if (last == null) {
      return (goal: goal, exerciseId: exerciseId, daysSince: null);
    }
    final days = dateOnly(now).difference(dateOnly(last)).inDays;
    if (days < goal.testIntervalDays) return null;
    return (goal: goal, exerciseId: exerciseId, daysSince: days);
  }

  Goal? get primaryGoal {
    for (final g in goals) {
      if (g.primary && g.status == GoalStatus.active) return g;
    }
    return null;
  }

  /// Resolves a goal marker against the log. Falls back to the baseline when
  /// nothing has been logged yet.
  MarkerReading readMarker(GoalMarker marker) {
    if (marker.metric == MarkerMetric.bodyweight) {
      final average = averageBodyweight();
      return MarkerReading(
        marker: marker,
        current: average ?? settings.bodyweightKg,
        hasData: average != null,
      );
    }

    final id = marker.exerciseId;
    if (id == null) {
      return MarkerReading(
        marker: marker,
        current: marker.baseline,
        hasData: false,
      );
    }

    final history = historyOf(id);
    if (history.isEmpty) {
      return MarkerReading(
        marker: marker,
        current: marker.baseline,
        hasData: false,
      );
    }

    final sets = history.first.workingSets;
    if (sets.isEmpty) {
      return MarkerReading(
        marker: marker,
        current: marker.baseline,
        hasData: false,
      );
    }

    double pick(double Function(SetEntry) f) {
      var best = f(sets.first);
      for (final s in sets) {
        final v = f(s);
        if (marker.lowerIsBetter ? v < best : v > best) best = v;
      }
      return best;
    }

    final current = switch (marker.metric) {
      MarkerMetric.topLoad => pick((s) => s.weight),
      MarkerMetric.topReps => pick((s) => s.reps.toDouble()),
      MarkerMetric.topDuration => pick(
        (s) => (s.durationSeconds ?? 0).toDouble(),
      ),
      MarkerMetric.topTempo => pick((s) => s.tempoSeconds ?? 0),
      MarkerMetric.bodyweight => settings.bodyweightKg,
    };

    return MarkerReading(marker: marker, current: current, hasData: true);
  }

  /// The next free G-number. The plan document numbers its goals G1..G7, so
  /// new ones carry on from there rather than restarting.
  String nextGoalCode() {
    var highest = 0;
    for (final g in goals) {
      final n = int.tryParse(g.code.replaceFirst(RegExp('^[Gg]'), '').trim());
      if (n != null && n > highest) highest = n;
    }
    return 'G${highest + 1}';
  }

  Goal createGoal({
    required String title,
    String? code,
    GoalType type = GoalType.general,
    String target = '',
    String notes = '',
    GoalStatus status = GoalStatus.active,
    bool primary = false,
    String? testExerciseId,
    int testIntervalDays = 14,
    List<GoalMarker>? markers,
    List<Milestone>? milestones,
  }) {
    final given = code?.trim() ?? '';
    final goal = Goal(
      code: given.isEmpty ? nextGoalCode() : given,
      title: title.trim(),
      type: type,
      target: target.trim(),
      notes: notes.trim(),
      status: status,
      startedAt: now,
      testExerciseId: testExerciseId,
      testIntervalDays: testIntervalDays,
      markers: markers ?? [],
      milestones: milestones ?? [],
    );
    goals.add(goal);
    if (primary) _makePrimary(goal);
    _touch();
    return goal;
  }

  /// Exactly one goal is primary, so setting one clears the rest.
  void _makePrimary(Goal goal) {
    for (final g in goals) {
      g.primary = g.id == goal.id;
    }
  }

  void updateGoal(
    Goal goal, {
    String? title,
    String? code,
    GoalType? type,
    String? target,
    GoalStatus? status,
    bool? primary,
    String? notes,
    Object? testExerciseId = _keep,
    int? testIntervalDays,
    List<GoalMarker>? markers,
    List<Milestone>? milestones,
  }) {
    if (title != null && title.trim().isNotEmpty) goal.title = title.trim();
    if (code != null && code.trim().isNotEmpty) goal.code = code.trim();
    if (type != null) goal.type = type;
    if (target != null) goal.target = target.trim();
    if (status != null) goal.status = status;
    if (primary == true) {
      _makePrimary(goal);
    } else if (primary == false) {
      goal.primary = false;
    }
    if (notes != null) goal.notes = notes.trim();
    if (!identical(testExerciseId, _keep)) {
      goal.testExerciseId = testExerciseId as String?;
    }
    if (testIntervalDays != null && testIntervalDays > 0) {
      goal.testIntervalDays = testIntervalDays;
    }
    if (markers != null) goal.markers = markers;
    if (milestones != null) goal.milestones = milestones;
    _touch();
  }

  /// Drops a goal and every routine's reference to it, so no plan day is left
  /// pointing at something that no longer exists.
  void deleteGoal(Goal goal) {
    goals.removeWhere((g) => g.id == goal.id);
    for (final day in plan.days) {
      day.goalIds.remove(goal.id);
    }
    _touch();
  }

  /// Which routines serve this goal. Stored on the plan day, because that is
  /// what the catch-up ordering reads.
  void setGoalDays(Goal goal, Set<String> dayIds) {
    for (final day in plan.days) {
      day.goalIds.remove(goal.id);
      if (dayIds.contains(day.id)) day.goalIds.add(goal.id);
    }
    _touch();
  }

  /// A marker pre-filled from the log: the metric this movement actually
  /// records, the direction that counts as progress, and today's best as the
  /// baseline so the goal starts from where you already are.
  GoalMarker suggestMarker(ExerciseDef def) {
    final metric = MarkerMetricInfo.forTracking(def.tracking);
    // Assistance runs backwards — less help is the harder set.
    final lowerIsBetter = def.inverted;
    final reading = readMarker(
      GoalMarker(
        label: '',
        metric: metric,
        exerciseId: def.id,
        baseline: 0,
        lowerIsBetter: lowerIsBetter,
      ),
    );
    return GoalMarker(
      label: switch (metric) {
        MarkerMetric.topLoad => def.name,
        MarkerMetric.topReps => '${def.name} reps',
        MarkerMetric.topDuration => '${def.name} hold',
        MarkerMetric.topTempo => '${def.name} descent',
        MarkerMetric.bodyweight => 'Bodyweight',
      },
      metric: metric,
      exerciseId: def.id,
      baseline: reading.hasData ? reading.current : 0,
      lowerIsBetter: lowerIsBetter,
      unit: metric.unit,
    );
  }

  /// Bodyweight is the one marker with no movement behind it.
  GoalMarker suggestBodyweightMarker() => GoalMarker(
    label: 'Bodyweight',
    metric: MarkerMetric.bodyweight,
    baseline: currentBodyweight,
    lowerIsBetter: true,
    unit: MarkerMetric.bodyweight.unit,
  );

  void toggleMilestone(Goal goal, Milestone milestone) {
    milestone.done = !milestone.done;
    _touch();
  }
}
