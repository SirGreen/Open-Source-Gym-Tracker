import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/data/progression.dart';
import 'package:gym_tracker/models/models.dart';

import 'helpers.dart';

void main() {
  group('scoring by tracking mode', () {
    test('loaded work is still an estimated 1RM', () async {
      final state = await seeded();
      final def = state.exerciseById('lat_pulldown');
      final set = SetEntry(weight: 24, reps: 12, done: true);

      expect(setScore(def, set, 80), closeTo(33.6, 0.001)); // 24 × (1 + 12/30)
      expect(formatScore(def, 33.6), '33.6 kg e1RM');
      expect(scoreAxisLabel(def), 'Estimated 1RM (kg)');
    });

    test('negatives are scored by descent time, not a phantom 1RM', () async {
      final state = await seeded();
      final def = state.exerciseById('pullup_negative');
      final set = SetEntry(reps: 5, tempoSeconds: 3, done: true);

      // Epley on an eccentric would have claimed 80 × (1 + 5/30) = 93.33 kg,
      // on the very movement the primary goal exists because you cannot do.
      expect(setScore(def, set, 80), 3);
      expect(formatScore(def, 3), '3 s descent');
      expect(scoreAxisLabel(def), 'Longest descent (s)');
    });

    test('bodyweight work is scored by reps', () async {
      final state = await seeded();
      final def = state.exerciseById('scap_pullup');
      final set = SetEntry(reps: 12, done: true);

      expect(setScore(def, set, 80), 12);
      expect(formatScore(def, 12), '12 reps');
      expect(scoreAxisLabel(def), 'Best set (reps)');
    });

    test('holds are scored by seconds', () async {
      final state = await seeded();
      final def = state.exerciseById('dead_hang');
      final set = SetEntry(durationSeconds: 45, done: true);

      expect(setScore(def, set, 80), 45);
      expect(formatScore(def, 45), '45 s hold');
    });

    test(
      'a slower descent is a record; more reps at the same tempo is not',
      () async {
        final state = await seeded();
        final pull = dayNamed(state, 'Pull Day');

        void negatives(int reps, double tempo) {
          final session = state.startFromDay(pull);
          final neg = session.exercises.firstWhere(
            (e) => e.exerciseId == 'pullup_negative',
          );
          session.exercises.removeWhere((e) => e.id != neg.id);
          neg.sets.removeRange(1, neg.sets.length);
          state.updateSet(
            neg.sets.single,
            reps: reps,
            tempoSeconds: tempo,
            done: true,
          );
          state.finishSession(session);
        }

        negatives(5, 2);
        expect(state.personalRecord('pullup_negative')!.score, 2);

        // Grinding out more reps at the same tempo is not the progression the
        // plan asks for, so it must not read as a personal best.
        final more = state.startFromDay(pull);
        final neg = more.exercises.firstWhere(
          (e) => e.exerciseId == 'pullup_negative',
        );
        state.updateSet(neg.sets.first, reps: 8, tempoSeconds: 2, done: true);
        expect(state.personalRecordIn(more, neg), isNull);

        state.updateSet(neg.sets.first, tempoSeconds: 3);
        final record = state.personalRecordIn(more, neg)!;
        expect(record.score, 3);
        expect(record.previousBest, 2);
      },
    );

    test('the chart and the G1 marker now agree on negatives', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      final session = state.startFromDay(pull);
      final neg = session.exercises.firstWhere(
        (e) => e.exerciseId == 'pullup_negative',
      );
      session.exercises.removeWhere((e) => e.id != neg.id);
      for (final set in neg.sets) {
        state.updateSet(set, reps: 5, tempoSeconds: 4, done: true);
      }
      state.finishSession(session);

      final marker = state.primaryGoal!.markers.firstWhere(
        (m) => m.label == 'Negative duration',
      );

      expect(state.pointsFor('pullup_negative').single.score, 4);
      expect(
        state.readMarker(marker).current,
        4,
        reason: 'one number, not two disagreeing ones',
      );
    });
  });

  group('personal records', () {
    test('the first completed set goes on the board', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      state.updateSet(pulldown.sets.first, weight: 24, reps: 12, done: true);

      final record = state.personalRecordIn(session, pulldown)!;
      expect(record.set, same(pulldown.sets.first));
      expect(record.previousBest, isNull);
    });

    test('beating history reports what it broke', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 12)],
        rpe: 8,
      );
      final oldBest = state.personalRecord('lat_pulldown')!.score;

      final session = state.startFromDay(pull);
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      state.updateSet(pulldown.sets.first, weight: 30, reps: 12, done: true);

      final record = state.personalRecordIn(session, pulldown)!;
      expect(record.previousBest, closeTo(oldBest, 0.001));
      expect(record.score, greaterThan(oldBest));
    });

    test('a lighter day is not a record', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(30, 12)],
        rpe: 8,
      );

      final session = state.startFromDay(pull);
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      state.updateSet(pulldown.sets.first, weight: 24, reps: 12, done: true);

      expect(state.personalRecordIn(session, pulldown), isNull);
    });

    test('only the session best is flagged, not every set', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      state.updateSet(pulldown.sets[0], weight: 24, reps: 12, done: true);
      state.updateSet(pulldown.sets[1], weight: 30, reps: 12, done: true);
      state.updateSet(pulldown.sets[2], weight: 26, reps: 12, done: true);

      expect(
        state.personalRecordIn(session, pulldown)!.set,
        same(pulldown.sets[1]),
      );
    });

    test('less assistance counts as a record', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'assisted_pullup',
        sets: [(55, 10)],
        rpe: 8,
      );

      final session = state.startFromDay(pull);
      final assisted = session.exercises.firstWhere(
        (e) => e.exerciseId == 'assisted_pullup',
      );
      state.updateSet(assisted.sets.first, weight: 45, reps: 10, done: true);

      expect(
        state.personalRecordIn(session, assisted),
        isNotNull,
        reason: 'a lower number is more of you doing the work',
      );
    });

    test('a longer hold counts as a record', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'dead_hang',
        sets: [(0, 0)],
        durationSeconds: 30,
      );

      final session = state.startFromDay(pull);
      final hang = session.exercises.firstWhere(
        (e) => e.exerciseId == 'dead_hang',
      );
      state.updateSet(hang.sets.first, durationSeconds: 45, done: true);

      final record = state.personalRecordIn(session, hang)!;
      expect(record.score, 45);
      expect(record.previousBest, 30);
    });

    test('a finished session is not measured against itself', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 12)],
        rpe: 8,
      );

      final session = state.finishedSessions.single;
      expect(
        state.personalRecordIn(session, session.exercises.single),
        isNotNull,
        reason: 'its own set must not count as the mark to beat',
      );
    });
  });

  group('energy estimate', () {
    /// A finished session of lat pulldowns, which the plan rests for 90 s.
    WorkoutSession pulldowns(AppState state, {int sets = 1, int reps = 10}) {
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final se = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      session.exercises.removeWhere((e) => e.id != se.id);
      se.sets.removeRange(1, se.sets.length);
      for (var i = 1; i < sets; i++) {
        state.addSet(se);
      }
      for (final set in se.sets) {
        state.updateSet(set, weight: 40, reps: reps, done: true);
      }
      state.finishSession(session);
      return session;
    }

    test('the time is the work and its rests, per set', () async {
      final state = await seeded();
      final session = pulldowns(state, sets: 3);

      expect(state.sessionEffort(session), const Duration(minutes: 6));
      expect(state.sessionCalories(session), closeTo(42, 0.001));
    });

    test('a heavier body pays more for the same work', () async {
      final state = await seeded();
      state.logBodyweight(100);
      final session = pulldowns(state);

      expect(state.bodyweightFor(session), 100);
      // The same two minutes, at 100 kg rather than 80.
      expect(state.sessionCalories(session), closeTo(17.5, 0.001));
    });

    test('it is read off the work, not the wall clock', () async {
      final state = await seeded();
      final session = pulldowns(state);
      final live = state.sessionCalories(session);

      // A workout typed up afterwards has no clock at all to read.
      session.end = session.start;

      expect(session.durationAt(state.now), Duration.zero);
      expect(
        state.sessionCalories(session),
        live,
        reason: 'the same work has to cost the same either way',
      );
    });

    test('a session with nothing ticked off burned nothing', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));

      expect(state.sessionEffort(session), Duration.zero);
      expect(state.sessionCalories(session), 0);
    });

    test('the week totals it up alongside the volume', () async {
      final state = await seeded();
      pulldowns(state, sets: 3);
      pulldowns(state, sets: 3);

      expect(state.weeklyVolume(1).last.kcal, closeTo(84, 0.001));
    });
  });

  group('strength trend', () {
    test('two sessions are not a direction', () {
      expect(verdictForScores([100, 105]), TrendVerdict.tooSoon);
      expect(verdictForScores([]), TrendVerdict.tooSoon);
    });

    test('a best in the last session is climbing', () {
      expect(verdictForScores([100, 102, 105]), TrendVerdict.climbing);
    });

    test('matching an old mark is not beating it', () {
      // Back to 105 after three sessions is not progress on a plan that asks
      // for a rep or a plate more each time.
      expect(verdictForScores([105, 100, 100, 105]), TrendVerdict.stalled);
    });

    test('a session or two off the best is only holding', () {
      expect(verdictForScores([100, 105, 104]), TrendVerdict.holding);
      expect(verdictForScores([100, 105, 104, 103]), TrendVerdict.holding);
    });

    test('three sessions without a new best is stuck', () {
      expect(verdictForScores([105, 104, 103, 102]), TrendVerdict.stalled);
    });

    test('well under the best is going backwards, not merely stuck', () {
      // 12% down over several sessions is a different problem from a plateau.
      expect(verdictForScores([100, 95, 90, 88]), TrendVerdict.slipping);
    });

    test('one bad session does not call a lift regressed', () {
      // Straight off a best, however far down — that is a bad day.
      expect(verdictForScores([100, 120, 80]), TrendVerdict.holding);
    });

    test('a dead flat lift is stuck, not climbing', () {
      // The case the stale-load rule already catches: same numbers, session
      // after session. The verdict must not contradict the note beside it.
      expect(verdictForScores([100, 100, 100, 100]), TrendVerdict.stalled);
      expect(verdictForScores([100, 100, 100, 99]), TrendVerdict.stalled);
    });

    test('the attention flag picks out exactly the two bad verdicts', () {
      expect(TrendVerdict.stalled.needsAttention, isTrue);
      expect(TrendVerdict.slipping.needsAttention, isTrue);
      expect(TrendVerdict.holding.needsAttention, isFalse);
      expect(TrendVerdict.climbing.needsAttention, isFalse);
      expect(TrendVerdict.tooSoon.needsAttention, isFalse);
    });

    test('the worst verdicts sort first', () {
      final order = [
        TrendVerdict.climbing,
        TrendVerdict.tooSoon,
        TrendVerdict.slipping,
        TrendVerdict.holding,
        TrendVerdict.stalled,
      ]..sort((a, b) => a.rank.compareTo(b.rank));

      expect(order, [
        TrendVerdict.slipping,
        TrendVerdict.stalled,
        TrendVerdict.holding,
        TrendVerdict.climbing,
        TrendVerdict.tooSoon,
      ]);
    });
  });

  group('trend dashboard', () {
    /// Logs [loads] as successive sessions of one lift, oldest first.
    Future<AppState> withLoads(List<double> loads) async {
      final state = await seeded();
      final day = dayNamed(state, 'Pull Day');
      for (final load in loads) {
        logSession(
          state,
          day,
          exerciseId: 'lat_pulldown',
          sets: [(load, 10)],
          rpe: 8,
        );
      }
      return state;
    }

    test('a lift climbing session on session reads as climbing', () async {
      final state = await withLoads([40, 45, 50]);
      final trend = state.exerciseTrends().firstWhere(
        (t) => t.def.id == 'lat_pulldown',
      );

      expect(trend.verdict, TrendVerdict.climbing);
      expect(trend.sessions, 3);
      expect(trend.sessionsSinceBest, 0);
      expect(trend.note, isNull);
    });

    test('a lift stuck at one load is flagged with what to do', () async {
      final state = await withLoads([50, 50, 50, 50]);
      final trend = state.exerciseTrends().firstWhere(
        (t) => t.def.id == 'lat_pulldown',
      );

      expect(trend.verdict, TrendVerdict.stalled);
      // Same load at RPE 8 three times running is the actionable case.
      expect(trend.note, contains('push the load'));
    });

    test('lifts needing attention come first', () async {
      final state = await seeded();
      final day = dayNamed(state, 'Pull Day');
      for (final load in [50.0, 50.0, 50.0, 49.0]) {
        logSession(
          state,
          day,
          exerciseId: 'lat_pulldown',
          sets: [(load, 10)],
          rpe: 8,
        );
      }
      for (final load in [30.0, 35.0, 40.0]) {
        logSession(
          state,
          day,
          exerciseId: 'seated_cable_row',
          sets: [(load, 10)],
          rpe: 8,
        );
      }

      final trends = state.exerciseTrends();
      expect(trends.first.verdict.needsAttention, isTrue);
      expect(trends.first.def.id, 'lat_pulldown');
    });

    test('sessions outside the window are not judged', () async {
      final state = await withLoads([50, 50, 50, 50]);
      final trends = state.exerciseTrends(days: 0);
      // Everything logged today still falls inside a zero-day window; the
      // point is only that the filter is applied at all.
      expect(trends, isNotEmpty);

      // Backdate every session well past any window and it drops out.
      for (final s in state.sessions) {
        s.start = s.start.subtract(const Duration(days: 400));
        s.end = s.end?.subtract(const Duration(days: 400));
      }
      expect(state.exerciseTrends(days: 120), isEmpty);
    });

    test('a lift with one session is kept but not called', () async {
      final state = await withLoads([50]);
      final trend = state.exerciseTrends().firstWhere(
        (t) => t.def.id == 'lat_pulldown',
      );

      expect(trend.verdict, TrendVerdict.tooSoon);
      expect(trend.sessions, 1);
    });
  });

  group('muscle coverage', () {
    final wednesday = DateTime(2026, 9, 2);

    MuscleVolume forMuscle(AppState state, MuscleGroup m) =>
        state.muscleCoverage().firstWhere((v) => v.muscle == m);

    test('the landmarks sort weekly sets into verdicts', () {
      expect(verdictFor(0), VolumeVerdict.untrained);
      expect(verdictFor(3.9), VolumeVerdict.neglected);
      expect(verdictFor(4), VolumeVerdict.maintaining);
      expect(verdictFor(9.9), VolumeVerdict.maintaining);
      expect(verdictFor(10), VolumeVerdict.productive);
      expect(verdictFor(20), VolumeVerdict.productive);
      expect(verdictFor(20.1), VolumeVerdict.high);

      expect(VolumeVerdict.neglected.isShort, isTrue);
      expect(
        VolumeVerdict.maintaining.isShort,
        isTrue,
        reason: 'holding is not building',
      );
      expect(VolumeVerdict.productive.isShort, isFalse);
    });

    test(
      'a synergist banks half a set, the target banks a whole one',
      () async {
        final state = await seededOn(wednesday);
        // Dumbbell bench: chest is the point, triceps and front delts assist.
        logSession(
          state,
          dayNamed(state, 'Push Day'),
          exerciseId: 'db_bench',
          sets: [(20.0, 10), (20.0, 10)],
        );

        // Four weeks of window, two hard sets in it.
        expect(
          forMuscle(state, MuscleGroup.chest).directSets,
          closeTo(0.5, 0.01),
        );
        expect(forMuscle(state, MuscleGroup.chest).indirectSets, 0);
        expect(
          forMuscle(state, MuscleGroup.triceps).indirectSets,
          closeTo(0.25, 0.01),
        );
        expect(forMuscle(state, MuscleGroup.triceps).directSets, 0);
        expect(
          forMuscle(state, MuscleGroup.shoulders).indirectSets,
          closeTo(0.25, 0.01),
        );
      },
    );

    test('indirect work keeps a muscle off the neglected list', () async {
      final state = await seededOn(wednesday);
      // Enough pressing that the triceps are well past maintenance on
      // assistance alone, without a single direct triceps set.
      for (var i = 0; i < 4; i++) {
        logSession(
          state,
          dayNamed(state, 'Push Day'),
          exerciseId: 'db_bench',
          sets: List.generate(10, (_) => (20.0, 10)),
        );
      }

      final triceps = forMuscle(state, MuscleGroup.triceps);
      expect(triceps.directSets, 0);
      expect(triceps.weeklySets, closeTo(5, 0.01));
      expect(
        triceps.verdict,
        VolumeVerdict.maintaining,
        reason: 'counting primaries alone would have called this neglected',
      );
    });

    test('warm-ups are not hard sets', () async {
      final state = await seededOn(wednesday);
      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      final se = session.exercises.firstWhere(
        (e) => e.exerciseId == 'db_bench',
      );
      session.exercises.removeWhere((e) => e.id != se.id);
      se.sets.clear();
      se.sets.add(SetEntry(weight: 10, reps: 10, done: true, warmup: true));
      se.sets.add(SetEntry(weight: 20, reps: 10, done: true));
      state.finishSession(session);

      expect(
        forMuscle(state, MuscleGroup.chest).directSets,
        closeTo(0.25, 0.01),
      );
    });

    test('a muscle with nothing logged reads as untrained', () async {
      final state = await seededOn(wednesday);
      final calves = forMuscle(state, MuscleGroup.calves);

      expect(calves.weeklySets, 0);
      expect(calves.verdict, VolumeVerdict.untrained);
      expect(calves.needsAttention, isTrue);
    });

    test('the worst-served muscles come first', () async {
      final state = await seededOn(wednesday);
      logSession(
        state,
        dayNamed(state, 'Push Day'),
        exerciseId: 'db_bench',
        sets: [(20.0, 10)],
      );

      final rows = state.muscleCoverage();
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i].weeklySets,
          greaterThanOrEqualTo(rows[i - 1].weeklySets),
        );
      }
      expect(rows.first.weeklySets, 0);
    });

    test('time off shows as neglect, but a young install does not', () async {
      final trained = await seededOn(wednesday);
      logSession(
        trained,
        dayNamed(trained, 'Push Day'),
        exerciseId: 'db_bench',
        sets: List.generate(8, (_) => (20.0, 10)),
      );
      // Eight sets spread over a four-week window is two a week.
      expect(
        forMuscle(trained, MuscleGroup.chest).directSets,
        closeTo(2, 0.01),
      );

      // The same eight sets on an install that is a fortnight old is four a
      // week — it has not been running long enough to have missed anything.
      final fresh = await seededOn(
        wednesday,
        trackingSince: wednesday.subtract(const Duration(days: 13)),
      );
      logSession(
        fresh,
        dayNamed(fresh, 'Push Day'),
        exerciseId: 'db_bench',
        sets: List.generate(8, (_) => (20.0, 10)),
      );
      expect(forMuscle(fresh, MuscleGroup.chest).directSets, closeTo(4, 0.01));
    });

    test('frequency counts distinct days, not sessions', () async {
      final state = await seededOn(wednesday);
      logSession(
        state,
        dayNamed(state, 'Push Day'),
        exerciseId: 'db_bench',
        sets: [(20.0, 10)],
      );
      logSession(
        state,
        dayNamed(state, 'Push Day'),
        exerciseId: 'db_bench',
        sets: [(20.0, 10)],
      );

      // Both landed on the same day, so it is one exposure, not two.
      expect(
        forMuscle(state, MuscleGroup.chest).sessionsPerWeek,
        closeTo(0.25, 0.01),
      );
    });

    test('the plan schedules no direct glute work', () async {
      final state = await seededOn(wednesday);
      final planned = state.plannedWeeklySets();

      expect(planned[MuscleGroup.glutes], anyOf(isNull, 0));
      expect(forMuscle(state, MuscleGroup.glutes).missingFromPlan, isTrue);
      expect(
        forMuscle(state, MuscleGroup.quads).missingFromPlan,
        isFalse,
        reason: 'leg day is built around them',
      );
    });

    test('a routine on two weekdays is scheduled twice', () async {
      final state = await seededOn(wednesday);
      final pull = dayNamed(state, 'Pull Day');
      expect(pull.weekdays, hasLength(2));

      final backSets = pull.activeItems
          .where(
            (i) => state.exerciseById(i.exerciseId).muscle == MuscleGroup.back,
          )
          .fold(0, (a, i) => a + i.sets);
      expect(
        state.plannedWeeklySets()[MuscleGroup.back],
        greaterThanOrEqualTo(backSets * 2),
      );
    });

    test(
      'an install seeded before synergists existed gets them back',
      () async {
        final state = await seeded();
        final json = state.toJson();
        for (final e in (json['exercises'] as List)) {
          (e as Map).remove('secondaryMuscles');
        }

        final restored = AppState(storage: MemoryStorage())..importFrom(json);

        expect(
          restored.exerciseById('db_bench').secondaryMuscles,
          containsAll([MuscleGroup.triceps, MuscleGroup.shoulders]),
        );
        expect(
          restored.exerciseById('lateral_raise').secondaryMuscles,
          isEmpty,
          reason: 'a true isolation has none to give',
        );
      },
    );

    test('a movement added by hand keeps its empty synergist list', () async {
      final state = await seeded();
      final made = state.addExercise(
        'Hip thrust',
        MuscleGroup.glutes,
        Equipment.barbell,
      );

      expect(made.secondaryMuscles, isEmpty);
      final json = state.toJson();
      final restored = AppState(storage: MemoryStorage())..importFrom(json);
      expect(restored.exerciseById(made.id).secondaryMuscles, isEmpty);
    });
  });
}
