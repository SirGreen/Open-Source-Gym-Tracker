import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/models/models.dart';

import 'helpers.dart';

void main() {
  group('progress and goals', () {
    test('tracks the score per session, oldest first', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      for (final w in [20.0, 24.0, 30.0]) {
        logSession(
          state,
          pull,
          exerciseId: 'lat_pulldown',
          sets: [(w, 10)],
          rpe: 8,
        );
      }

      final points = state.pointsFor('lat_pulldown');
      expect(points, hasLength(3));
      expect(points.first.topWeight, 20.0);
      expect(points.last.topWeight, 30.0);
      expect(points.last.score, greaterThan(points.first.score));
      expect(state.personalRecord('lat_pulldown')!.topWeight, 30.0);
    });

    test('dead hangs are scored in seconds', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'dead_hang',
        sets: [(0, 0)],
        durationSeconds: 42,
      );

      final points = state.pointsFor('dead_hang');
      expect(points.single.score, 42);
      expect(points.single.topDuration, 42);
      expect(points.single.volume, 0);
    });

    test('the assistance marker counts downward as progress', () async {
      final state = await seeded();
      final g1 = state.primaryGoal!;
      final assist = g1.markers.firstWhere(
        (m) => m.label == 'Assistance weight',
      );

      expect(state.readMarker(assist).current, 55, reason: 'baseline first');

      logSession(
        state,
        dayNamed(state, 'Pull Day'),
        exerciseId: 'assisted_pullup',
        sets: [(45, 10)],
        rpe: 8,
      );

      final reading = state.readMarker(assist);
      expect(reading.current, 45);
      expect(reading.improved, isTrue);
    });

    test('the bodyweight marker reads the latest session weight', () async {
      final state = await seeded();
      state.updateSettings(bodyweightKg: 78);
      logSession(
        state,
        dayNamed(state, 'Pull Day'),
        exerciseId: 'lat_pulldown',
        sets: [(24, 12)],
        rpe: 8,
      );

      final g1 = state.primaryGoal!;
      final marker = g1.markers.firstWhere((m) => m.label == 'Bodyweight');
      final reading = state.readMarker(marker);
      expect(reading.current, 78);
      expect(reading.improved, isTrue);
    });

    test(
      'weekly volume and muscle breakdown land in the current week',
      () async {
        final state = await seeded();
        logSession(
          state,
          dayNamed(state, 'Pull Day'),
          exerciseId: 'lat_pulldown',
          sets: [(24, 10), (24, 10)],
          rpe: 8,
        );

        expect(state.thisWeekVolume, 480);
        expect(state.weeklyVolume(4).last.sessions, 1);
        expect(state.weekStreak, 1);

        final breakdown = state.muscleBreakdown(28);
        expect(breakdown.single.muscle, MuscleGroup.back);
        expect(breakdown.single.sets, 2);
      },
    );

    test('only one goal can be primary', () async {
      final state = await seeded();
      final g5 = state.goals.firstWhere((g) => g.code == 'G5');
      state.updateGoal(g5, primary: true, status: GoalStatus.active);

      expect(state.goals.where((g) => g.primary), hasLength(1));
      expect(state.primaryGoal!.code, 'G5');
    });
  });

  group('goal check-in', () {
    final wednesday = DateTime(2026, 9, 2);

    /// Logs one unassisted pull-up attempt, dated.
    void attempt(AppState state, DateTime date, int reps) {
      final session = state.startEmptySession();
      final se = state.addExerciseToSession(session, 'unassisted_pullup');
      se.sets.removeRange(1, se.sets.length);
      state.updateSet(se.sets.single, reps: reps, done: true);
      state.finishSession(session);
      session.start = date;
      session.end = date;
    }

    test('never attempted means it is due immediately', () async {
      final state = await seededOn(wednesday);
      final due = state.dueGoalTest!;

      expect(due.goal.code, 'G1');
      expect(due.exerciseId, 'unassisted_pullup');
      expect(due.daysSince, isNull);
    });

    test('an attempt today clears it', () async {
      final state = await seededOn(wednesday);
      attempt(state, wednesday, 0);

      expect(state.dueGoalTest, isNull);
      expect(state.lastPerformedAt('unassisted_pullup'), wednesday);
    });

    test('a failed attempt still counts as the measurement', () async {
      final state = await seededOn(wednesday);
      attempt(state, wednesday, 0);

      expect(
        state.dueGoalTest,
        isNull,
        reason: 'zero reps is a data point, not a non-event',
      );
      expect(state.pointsFor('unassisted_pullup'), hasLength(1));
    });

    test('it comes back after the interval', () async {
      final state = await seededOn(wednesday);
      attempt(state, wednesday.subtract(const Duration(days: 13)), 0);
      expect(state.dueGoalTest, isNull);

      attempt(state, wednesday.subtract(const Duration(days: 14)), 0);
      // The newest attempt is still 13 days old, so nothing is due yet.
      expect(state.dueGoalTest, isNull);

      final later = AppState(
        storage: MemoryStorage(),
        clock: () => wednesday.add(const Duration(days: 2)),
      );
      await later.load();
      attempt(later, wednesday.subtract(const Duration(days: 13)), 0);

      expect(later.dueGoalTest?.daysSince, 15);
    });

    test('the attempt goes to the front of the session', () async {
      final state = await seededOn(wednesday);
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final se = state.addExerciseToSession(
        session,
        'unassisted_pullup',
        first: true,
      );

      expect(
        session.exercises.first,
        same(se),
        reason: 'testing after an hour of pulling measures fatigue',
      );
    });

    test('reps feed the goal marker and set a record', () async {
      final state = await seededOn(wednesday);
      final marker = state.primaryGoal!.markers.firstWhere(
        (m) => m.label == 'Unassisted reps',
      );
      expect(state.readMarker(marker).current, 0);

      attempt(state, wednesday, 1);

      final reading = state.readMarker(marker);
      expect(reading.current, 1);
      expect(reading.improved, isTrue);
      expect(state.personalRecord('unassisted_pullup'), isNotNull);
    });

    test('a goal without a test exercise never asks', () async {
      final state = await seededOn(wednesday);
      state.primaryGoal!.testExerciseId = null;
      expect(state.dueGoalTest, isNull);
    });
  });

  group('goal achieved', () {
    test('only the move into achieved is a new achievement', () async {
      final state = await seeded();
      final goal = state.goals.firstWhere((g) => g.primary);

      expect(goal.status, isNot(GoalStatus.achieved));
      state.updateGoal(goal, status: GoalStatus.achieved);
      expect(goal.status, GoalStatus.achieved);

      // Setting it again is not a second achievement — the celebration must
      // not be something you can set off on demand.
      state.updateGoal(goal, status: GoalStatus.achieved);
      expect(goal.status, GoalStatus.achieved);
    });

    test(
      'markers that moved the right way are the ones worth showing',
      () async {
        final state = await seeded();
        final goal = state.goals.firstWhere((g) => g.markers.isNotEmpty);

        final readings = goal.markers.map(state.readMarker).toList();
        for (final r in readings) {
          // Improvement is measured in the goal's own direction: assistance and
          // bodyweight both get better by going down.
          expect(r.improved, r.progressDelta > 0.0001);
        }
      },
    );
  });

  group('creating goals', () {
    test('a new goal carries on from the plan document numbering', () async {
      final state = await seeded();
      expect(state.goals.map((g) => g.code), contains('G7'));

      final goal = state.createGoal(title: 'Ride 100 km');

      expect(goal.code, 'G8');
      expect(state.createGoal(title: 'Touch toes').code, 'G9');
      expect(goal.status, GoalStatus.active);
      expect(goal.primary, isFalse);
    });

    test('an explicit code is kept, and a blank one is filled in', () async {
      final state = await seeded();
      expect(state.createGoal(title: 'A', code: 'X1').code, 'X1');
      expect(state.createGoal(title: 'B', code: '   ').code, 'G8');
    });

    test('making a new goal primary displaces the old one', () async {
      final state = await seeded();
      final was = state.primaryGoal!;
      expect(was.code, 'G1');

      final goal = state.createGoal(title: 'Front lever', primary: true);

      expect(state.primaryGoal!.id, goal.id);
      expect(was.primary, isFalse);
      expect(state.goals.where((g) => g.primary), hasLength(1));
    });

    test('a marker starts from what the log already shows', () async {
      final state = await seeded();
      logSession(
        state,
        dayNamed(state, 'Pull Day'),
        exerciseId: 'lat_pulldown',
        sets: [(27.0, 10), (29.0, 8)],
      );

      final marker = state.suggestMarker(state.exerciseById('lat_pulldown'));

      expect(marker.metric, MarkerMetric.topLoad);
      expect(marker.baseline, 29);
      expect(marker.lowerIsBetter, isFalse);
      expect(marker.unit, 'kg');
      expect(marker.label, 'Lat pulldown');
    });

    test('an assistance marker counts down', () async {
      final state = await seeded();
      final marker = state.suggestMarker(state.exerciseById('assisted_pullup'));

      expect(
        marker.lowerIsBetter,
        isTrue,
        reason: 'less help is the harder set',
      );
    });

    test('a movement never trained starts the marker at zero', () async {
      final state = await seeded();
      final marker = state.suggestMarker(
        state.exerciseById('unassisted_pullup'),
      );

      expect(marker.baseline, 0);
      expect(state.readMarker(marker).hasData, isFalse);
    });

    test('the metric follows what the movement records', () async {
      final state = await seeded();
      MarkerMetric of(String id) =>
          state.suggestMarker(state.exerciseById(id)).metric;

      expect(of('unassisted_pullup'), MarkerMetric.topReps);
      expect(of('pullup_negative'), MarkerMetric.topTempo);
      expect(of('lat_pulldown'), MarkerMetric.topLoad);
    });

    test('the bodyweight marker needs no movement', () async {
      final state = await seeded();
      state.logBodyweight(78.4, date: DateTime(2026, 9, 1));

      final marker = state.suggestBodyweightMarker();

      expect(marker.metric, MarkerMetric.bodyweight);
      expect(marker.exerciseId, isNull);
      expect(marker.baseline, closeTo(78.4, 0.01));
      expect(marker.lowerIsBetter, isTrue);
    });

    test('editing rewrites the goal in place', () async {
      final state = await seeded();
      final goal = state.createGoal(title: 'Rows', target: '60 kg');

      state.updateGoal(
        goal,
        title: '  Heavy rows  ',
        target: '70 kg',
        type: GoalType.strengthMilestone,
        notes: 'chest supported',
      );

      expect(goal.title, 'Heavy rows', reason: 'trimmed');
      expect(goal.target, '70 kg');
      expect(goal.type, GoalType.strengthMilestone);
      expect(goal.notes, 'chest supported');
      expect(state.goals.where((g) => g.id == goal.id), hasLength(1));
    });

    test('a blank title never overwrites the one that is there', () async {
      final state = await seeded();
      final goal = state.createGoal(title: 'Dead hang 60 s');
      state.updateGoal(goal, title: '   ');
      expect(goal.title, 'Dead hang 60 s');
    });

    test('the test movement can be set and cleared', () async {
      final state = await seeded();
      final goal = state.createGoal(title: 'Hold', primary: true);
      expect(state.dueGoalTest, isNull);

      state.updateGoal(goal, testExerciseId: 'dead_hang', testIntervalDays: 7);
      expect(goal.testExerciseId, 'dead_hang');
      expect(goal.testIntervalDays, 7);
      expect(state.dueGoalTest?.goal.id, goal.id);

      // Untouched by an update that does not mention it.
      state.updateGoal(goal, notes: 'unchanged');
      expect(goal.testExerciseId, 'dead_hang');

      state.updateGoal(goal, testExerciseId: null);
      expect(goal.testExerciseId, isNull);
      expect(state.dueGoalTest, isNull);
    });

    test('the routines serving a goal are replaced wholesale', () async {
      final state = await seeded();
      final goal = state.createGoal(title: 'Bigger arms');
      final pull = dayNamed(state, 'Pull Day');
      final push = dayNamed(state, 'Push Day');

      state.setGoalDays(goal, {pull.id});
      expect(pull.goalIds, contains(goal.id));

      state.setGoalDays(goal, {push.id});
      expect(pull.goalIds, isNot(contains(goal.id)));
      expect(push.goalIds, contains(goal.id));

      state.setGoalDays(goal, {});
      expect(state.plan.days.any((d) => d.goalIds.contains(goal.id)), isFalse);
    });

    test('deleting a goal unhooks it from every routine', () async {
      final state = await seeded();
      final goal = state.goals.firstWhere((g) => g.code == 'G1');
      expect(state.plan.days.any((d) => d.goalIds.contains(goal.id)), isTrue);

      state.deleteGoal(goal);

      expect(state.goalById(goal.id), isNull);
      expect(state.plan.days.any((d) => d.goalIds.contains(goal.id)), isFalse);
      expect(state.primaryGoal, isNull);
    });

    test('a created goal survives a backup round-trip', () async {
      final state = await seeded();
      final goal = state.createGoal(
        title: 'Front lever',
        type: GoalType.skill,
        target: 'tuck hold 10 s',
        primary: true,
        testExerciseId: 'dead_hang',
        testIntervalDays: 21,
        markers: [state.suggestMarker(state.exerciseById('dead_hang'))],
        milestones: [Milestone(label: 'Tuck 5 s')],
      );

      final restored = AppState(storage: MemoryStorage())
        ..importFrom(state.toJson());
      final back = restored.goals.firstWhere((g) => g.code == goal.code);

      expect(back.title, 'Front lever');
      expect(back.type, GoalType.skill);
      expect(back.primary, isTrue);
      expect(back.testExerciseId, 'dead_hang');
      expect(back.testIntervalDays, 21);
      expect(back.markers.single.metric, MarkerMetric.topDuration);
      expect(back.milestones.single.label, 'Tuck 5 s');
    });
  });
}
