import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/data/progression.dart';
import 'package:gym_tracker/models/models.dart';
import 'package:gym_tracker/utils/formatting.dart' as fmt;

import 'helpers.dart';

void main() {
  group('backfilling a forgotten day', () {
    final monday = DateTime(2026, 8, 31);
    final wednesday = DateTime(2026, 9, 2);
    final friday = DateTime(2026, 9, 4);
    final saturday = DateTime(2026, 9, 5);

    /// One dated pull session with a single lat pulldown set.
    void pullOn(
      AppState state,
      DateTime date,
      double weight,
      int reps, {
      double? rpe,
    }) {
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final se = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      session.exercises.removeWhere((e) => e.id != se.id);
      se.sets.removeRange(1, se.sets.length);
      state.updateSet(se.sets.single, weight: weight, reps: reps, done: true);
      if (rpe != null) state.setLastSetRpe(se, rpe);
      state.finishSession(session);
      session.start = date;
      session.end = date;
    }

    test('it lands on the day it happened, already finished', () async {
      final state = await seededOn(saturday);
      final session = state.backfillSession(
        monday,
        day: dayNamed(state, 'Pull Day'),
      );

      expect(session.isActive, isFalse, reason: 'history, not in progress');
      expect(state.activeSession, isNull);
      expect(fmt.sameDay(session.start, monday), isTrue);
      expect(session.title, 'Pull Day');
      expect(session.exercises, isNotEmpty);
    });

    test('sets start unticked — you fill in what you did', () async {
      final state = await seededOn(saturday);
      final session = state.backfillSession(
        monday,
        day: dayNamed(state, 'Pull Day'),
      );

      expect(session.exercises.every((e) => e.doneCount == 0), isTrue);
      expect(
        state.trainedOn(monday),
        isFalse,
        reason: 'an empty session is not a workout',
      );
      expect(state.statusOf(monday), DayStatus.missed);
    });

    test('ticking it makes the day count and clears the debt', () async {
      final state = await seededOn(saturday);
      expect(state.outstandingMakeUps().map((m) => m.date), contains(monday));

      final session = state.backfillSession(
        monday,
        day: dayNamed(state, 'Pull Day'),
      );
      final first = session.exercises.first;
      state.completeSet(first, first.sets.first);

      expect(state.trainedOn(monday), isTrue);
      expect(state.statusOf(monday), DayStatus.trained);
      expect(
        state.outstandingMakeUps().map((m) => m.date),
        isNot(contains(monday)),
      );
    });

    test('abandoning it leaves nothing behind', () async {
      final state = await seededOn(saturday);
      final session = state.backfillSession(
        monday,
        day: dayNamed(state, 'Pull Day'),
      );

      expect(state.tidyFinishedSession(session), isFalse);
      expect(state.sessions, isEmpty);
      expect(state.statusOf(monday), DayStatus.missed);
    });

    test('it prefills from before that day, not after it', () async {
      final state = await seededOn(saturday);
      pullOn(state, monday, 24, 12);
      pullOn(state, friday, 30, 12);

      final session = state.backfillSession(
        wednesday,
        day: dayNamed(state, 'Pull Day'),
      );
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );

      expect(
        pulldown.sets.first.weight,
        24,
        reason: "Friday's 30 kg had not happened yet on Wednesday",
      );
    });

    test('it never invents a load increase', () async {
      final state = await seededOn(saturday);
      // A qualifying Monday would normally step the next session up.
      pullOn(state, monday, 24, 15, rpe: 8);
      expect(state.adviceFor('lat_pulldown', 15).kind, AdviceKind.increase);

      final session = state.backfillSession(
        wednesday,
        day: dayNamed(state, 'Pull Day'),
      );
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );

      expect(
        pulldown.autoProgressed,
        isFalse,
        reason: 'you already know what you lifted that day',
      );
      expect(pulldown.sets.first.weight, 24);
    });

    test('a day with no routine can be logged as a blank session', () async {
      final state = await seededOn(saturday);
      final thursday = DateTime(2026, 9, 3);
      final session = state.backfillSession(thursday);

      expect(session.title, 'Freestyle');
      expect(session.exercises, isEmpty);
      expect(session.planDayId, isNull);
      expect(fmt.sameDay(session.start, thursday), isTrue);
    });

    test(
      'a recorded reason survives, in case the backfill is abandoned',
      () async {
        final state = await seededOn(saturday);
        state.markMissed(monday, reason: MissReason.work);

        final session = state.backfillSession(
          monday,
          day: dayNamed(state, 'Pull Day'),
        );
        final first = session.exercises.first;
        state.completeSet(first, first.sets.first);

        expect(
          state.statusOf(monday),
          DayStatus.trained,
          reason: 'training wins over the marker',
        );
        expect(
          state.missedOn(monday),
          isNotNull,
          reason: 'kept, so abandoning the backfill restores the reason',
        );
      },
    );

    test('history lookups can be bounded by date', () async {
      final state = await seededOn(saturday);
      pullOn(state, monday, 24, 12);
      pullOn(state, friday, 30, 12);

      expect(state.historyOf('lat_pulldown'), hasLength(2));
      expect(state.historyOf('lat_pulldown', before: wednesday), hasLength(1));
      expect(
        state
            .lastPerformance('lat_pulldown', before: wednesday)!
            .sets
            .single
            .weight,
        24,
      );
    });
  });

  group('missed days', () {
    // 2026-08-31 is a Monday, so this week runs Mon Pull · Tue Push ·
    // Wed Legs · Thu rest · Fri Pull · Sat Push|Legs · Sun rest.
    // Midnight, because a MakeUp is dated to the day, not the moment.
    final monday = DateTime(2026, 8, 31);
    final tuesday = DateTime(2026, 9, 1);
    final wednesday = DateTime(2026, 9, 2);
    final friday = DateTime(2026, 9, 4);
    final saturday = DateTime(2026, 9, 5);

    test('a past scheduled day with nothing logged reads as missed', () async {
      final state = await seededOn(wednesday);

      expect(state.statusOf(monday), DayStatus.missed);
      expect(state.statusOf(wednesday), DayStatus.today);
      expect(state.statusOf(friday), DayStatus.scheduled);
      expect(state.statusOf(DateTime(2026, 9, 3)), DayStatus.rest);
    });

    test('training the day clears the miss', () async {
      final state = await seededOn(wednesday);
      logOn(state, monday, dayNamed(state, 'Pull Day'));

      expect(state.trainedOn(monday), isTrue);
      expect(state.statusOf(monday), DayStatus.trained);
      expect(
        state.outstandingMakeUps().map((m) => m.date),
        isNot(contains(monday)),
      );
    });

    test('a reason is recorded and updated in place', () async {
      final state = await seededOn(wednesday);

      state.markMissed(monday, reason: MissReason.work, note: 'late meeting');
      state.markMissed(monday, reason: MissReason.illness);

      expect(state.missedDays, hasLength(1));
      final record = state.missedOn(monday)!;
      expect(record.reason, MissReason.illness);
      expect(record.note, isEmpty);
      expect(state.statusOf(monday), DayStatus.missed);

      state.clearMissed(monday);
      expect(state.missedDays, isEmpty);
    });

    test('writing a day off takes it out of the owed list', () async {
      final state = await seededOn(wednesday);
      expect(state.outstandingMakeUps().map((m) => m.date), contains(monday));

      state.markMissed(monday, reason: MissReason.illness, writtenOff: true);

      expect(state.statusOf(monday), DayStatus.writtenOff);
      expect(
        state.outstandingMakeUps().map((m) => m.date),
        isNot(contains(monday)),
      );
    });

    test('primary-goal work is owed before older sessions', () async {
      final state = await seededOn(saturday);
      // Nothing trained all week: Mon Pull, Tue Push, Wed Legs, Fri Pull.
      final owed = state.outstandingMakeUps();

      expect(owed.map((m) => m.options.first.name), [
        'Pull Day',
        'Pull Day',
        'Push Day',
        'Leg Day',
      ]);
      expect(owed.map((m) => m.date), [monday, friday, tuesday, wednesday]);
      expect(
        owed.first.servesPrimaryGoal,
        isTrue,
        reason: 'pull serves G1, the primary goal',
      );
      expect(owed.last.servesPrimaryGoal, isFalse);
    });

    test('rest days are never owed and today is never overdue', () async {
      final state = await seededOn(wednesday);
      final owed = state.outstandingMakeUps();

      expect(owed.map((m) => m.date), [monday, tuesday]);
      expect(owed.map((m) => m.date), isNot(contains(wednesday)));
    });

    test('marking today missed keeps it off the owed list', () async {
      final state = await seededOn(wednesday);
      state.markMissed(wednesday, reason: MissReason.travel);

      expect(state.statusOf(wednesday), DayStatus.missed);
      expect(
        state.outstandingMakeUps().map((m) => m.date),
        isNot(contains(wednesday)),
      );
    });

    test('a choice day is owed once, with both options', () async {
      final state = await seededOn(DateTime(2026, 9, 6)); // Sunday
      final owed = state
          .outstandingMakeUps()
          .where((m) => m.date == saturday)
          .toList();

      expect(owed, hasLength(1));
      expect(
        owed.single.options.map((d) => d.name),
        containsAll(['Push Day', 'Leg Day']),
      );
    });

    test('back-to-back training is counted for the rest rule', () async {
      final state = await seededOn(wednesday);
      expect(state.consecutiveTrainingDays(), 0);
      expect(state.restIsDue, isFalse);

      logOn(state, monday, dayNamed(state, 'Pull Day'));
      logOn(state, tuesday, dayNamed(state, 'Push Day'));
      logOn(state, wednesday, dayNamed(state, 'Leg Day'));

      expect(state.consecutiveTrainingDays(), 3);
      expect(
        state.restIsDue,
        isTrue,
        reason: 'the plan asks for a rest day every 3-4 sessions',
      );
    });

    test('a gap breaks the back-to-back count', () async {
      final state = await seededOn(wednesday);
      logOn(state, monday, dayNamed(state, 'Pull Day'));
      logOn(state, wednesday, dayNamed(state, 'Leg Day'));

      expect(state.consecutiveTrainingDays(), 1, reason: 'Tuesday was a gap');
      expect(state.restIsDue, isFalse);
    });

    test('a fresh install owes nothing for days before it existed', () async {
      final state = AppState(storage: MemoryStorage(), clock: () => wednesday);
      await state.load();

      expect(state.settings.trackingSince, wednesday);
      expect(state.statusOf(monday), DayStatus.untracked);
      expect(state.outstandingMakeUps(), isEmpty);
    });

    test('an explicit mark counts even before tracking began', () async {
      final state = AppState(storage: MemoryStorage(), clock: () => wednesday);
      await state.load();
      state.markMissed(monday, reason: MissReason.work);

      expect(state.statusOf(monday), DayStatus.missed);
      expect(state.outstandingMakeUps().map((m) => m.date), contains(monday));
    });

    test('missed days survive a backup and clear with history', () async {
      final state = await seededOn(wednesday);
      state.markMissed(
        monday,
        reason: MissReason.gymClosed,
        note: 'refurb',
        writtenOff: true,
      );

      final restored = AppState(
        storage: MemoryStorage(),
        clock: () => wednesday,
      )..importFrom(state.toJson());

      final record = restored.missedOn(monday)!;
      expect(record.reason, MissReason.gymClosed);
      expect(record.note, 'refurb');
      expect(record.writtenOff, isTrue);

      restored.clearHistory();
      expect(restored.missedDays, isEmpty);
    });

    test('trained routines are reported by plan day', () async {
      final state = await seededOn(wednesday);
      expect(state.routinesTrainedOn(wednesday), isEmpty);

      logSession(
        state,
        dayNamed(state, 'Leg Day'),
        exerciseId: 'leg_press',
        sets: [(60.0, 10)],
      );

      expect(state.routinesTrainedOn(wednesday), {
        dayNamed(state, 'Leg Day').id,
      });
      expect(
        state.routinesTrainedOn(monday),
        isEmpty,
        reason: 'a different day owns its own sessions',
      );
    });

    test('a session with nothing ticked reports no routine', () async {
      final state = await seededOn(wednesday);
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      for (final e in session.exercises) {
        for (final set in e.sets) {
          set.done = false;
        }
      }
      state.finishSession(session);

      expect(state.routinesTrainedOn(wednesday), isEmpty);
      expect(state.trainedOn(wednesday), isFalse);
    });

    test(
      'a freestyle session counts as trained but claims no routine',
      () async {
        final state = await seededOn(wednesday);
        final session = state.startEmptySession();
        state.addExerciseToSession(session, 'leg_press');
        final se = session.exercises.first;
        state.completeSet(se, se.sets.first);
        state.finishSession(session);

        expect(state.trainedOn(wednesday), isTrue);
        expect(state.routinesTrainedOn(wednesday), isEmpty);
      },
    );

    test('a day taken as rest is not a miss and is not owed', () async {
      final state = await seededOn(wednesday);
      expect(state.outstandingMakeUps().map((m) => m.date), contains(monday));

      final record = state.markRest(monday);

      expect(record.isRest, isTrue);
      expect(
        record.writtenOff,
        isTrue,
        reason: 'rest is a decision, so nothing is owed for it',
      );
      expect(state.statusOf(monday), DayStatus.restTaken);
      expect(
        state.outstandingMakeUps().map((m) => m.date),
        isNot(contains(monday)),
      );
    });

    test('rest is never offered as an excuse', () async {
      expect(MissReasonInfo.excuses, isNot(contains(MissReason.rest)));
      expect(MissReasonInfo.excuses, hasLength(MissReason.values.length - 1));
      expect(
        MissReason.rest.suggestsRest,
        isFalse,
        reason: 'it is the rest, not a reason to take one',
      );
    });

    test('taking today as rest breaks the back-to-back count', () async {
      final state = await seededOn(wednesday);
      logOn(state, monday, dayNamed(state, 'Pull Day'));
      logOn(state, tuesday, dayNamed(state, 'Push Day'));

      state.markRest(wednesday);

      expect(state.statusOf(wednesday), DayStatus.restTaken);
      expect(state.consecutiveTrainingDays(), 0);
      expect(state.restIsDue, isFalse);
    });

    test('a rest day can be turned back into an owed session', () async {
      final state = await seededOn(wednesday);
      state.markRest(monday);
      state.markMissed(monday, reason: MissReason.work);

      expect(state.missedDays, hasLength(1));
      expect(state.missedOn(monday)!.isRest, isFalse);
      expect(state.statusOf(monday), DayStatus.missed);
      expect(state.outstandingMakeUps().map((m) => m.date), contains(monday));
    });

    test('training a day marked as rest still reads as trained', () async {
      final state = await seededOn(wednesday);
      state.markRest(monday);
      logOn(state, monday, dayNamed(state, 'Pull Day'));

      expect(state.statusOf(monday), DayStatus.trained);
    });

    test('a rest day survives a backup', () async {
      final state = await seededOn(wednesday);
      state.markRest(monday, note: 'shoulder felt cranky');

      final restored = AppState(
        storage: MemoryStorage(),
        clock: () => wednesday,
      )..importFrom(state.toJson());

      final record = restored.missedOn(monday)!;
      expect(record.isRest, isTrue);
      expect(record.note, 'shoulder felt cranky');
      expect(restored.statusOf(monday), DayStatus.restTaken);
    });
  });

  group('training reminders', () {
    final monday = DateTime(2026, 8, 31);

    test('only offers days the plan actually schedules', () async {
      final state = await seededOn(monday);
      final upcoming = state.upcomingTrainingDays();

      expect(upcoming, isNotEmpty);
      for (final day in upcoming) {
        expect(state.plan.daysForWeekday(day.date.weekday), isNotEmpty);
        expect(day.days, isNotEmpty);
      }
      // Thursday and Sunday are rest in the seeded plan.
      expect(
        upcoming.map((d) => d.date.weekday),
        isNot(anyElement(anyOf(DateTime.thursday, DateTime.sunday))),
      );
    });

    test('a choice day names both routines', () async {
      final state = await seededOn(monday);
      final saturday = state.upcomingTrainingDays().firstWhere(
        (d) => d.date.weekday == DateTime.saturday,
      );

      expect(saturday.days.length, 2);
      expect(saturday.title, 'Push Day or Leg Day');
    });

    test('a day already trained is not worth a reminder', () async {
      final state = await seededOn(monday);
      expect(state.upcomingTrainingDays().first.date, monday);

      logOn(state, monday, dayNamed(state, 'Pull Day'));
      expect(
        state.upcomingTrainingDays().first.date,
        monday.add(const Duration(days: 1)),
      );
    });

    test('rest taken and days written off are skipped', () async {
      final state = await seededOn(monday);
      final tuesday = monday.add(const Duration(days: 1));

      state.markRest(monday);
      state.markMissed(tuesday, reason: MissReason.travel, writtenOff: true);

      final dates = state.upcomingTrainingDays().map((d) => d.date);
      expect(dates, isNot(contains(monday)));
      expect(dates, isNot(contains(tuesday)));
    });

    test('the horizon is respected', () async {
      final state = await seededOn(monday);
      final upcoming = state.upcomingTrainingDays(days: 7);

      expect(upcoming, isNotEmpty);
      for (final day in upcoming) {
        expect(day.date.difference(monday).inDays, lessThan(7));
      }
    });
  });
}
