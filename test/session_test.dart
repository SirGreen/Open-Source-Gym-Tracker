import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/data/progression.dart';
import 'package:gym_tracker/models/models.dart';

import 'helpers.dart';

void main() {
  group('training by need', () {
    final wednesday = DateTime(2026, 9, 2);

    /// Four weeks of nothing but leg press: quads at 3 sets a week, its
    /// synergists — glutes and adductors — at half that, the rest untouched.
    Future<AppState> legPressOnly({DateTime? trackingSince}) async {
      final state = await seededOn(wednesday, trackingSince: trackingSince);
      logSession(
        state,
        dayNamed(state, 'Leg Day'),
        exerciseId: 'leg_press',
        sets: List.generate(12, (_) => (50.0, 12)),
      );
      return state;
    }

    List<String> idsOf(WorkoutSession s) => [
      for (final e in s.exercises) e.exerciseId,
    ];

    test('the most under-trained muscle goes first, core stays last', () async {
      final state = await legPressOnly();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      final planned = idsOf(session);

      expect(state.orderByNeed(session), isNotNull);
      final ordered = idsOf(session);

      expect(
        ordered.first,
        'hip_abductor',
        reason: 'untrained, and the first such in the plan',
      );
      expect(
        ordered.indexOf('hip_adductor'),
        greaterThan(ordered.indexOf('seated_calf_raise')),
        reason: 'adductors bank half of every leg press set; calves bank none',
      );
      expect(
        ordered.indexOf('leg_press'),
        lessThan(ordered.indexOf('bulgarian_split_squat')),
        reason: 'equal need keeps the plan order',
      );
      expect(ordered.sublist(ordered.length - 2), ['dead_bug', 'cable_crunch']);
      expect(ordered.toSet(), planned.toSet());
    });

    test('work already under way keeps its place', () async {
      final state = await legPressOnly();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      final started = session.exercises.first;
      state.completeSet(started, started.sets.first);

      state.orderByNeed(session);

      expect(session.exercises.first.id, started.id);
      expect(session.exercises[1].exerciseId, 'hip_abductor');
    });

    test('undo puts the plan order back, keeping anything added', () async {
      final state = await legPressOnly();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      final planned = idsOf(session);

      final before = state.orderByNeed(session)!;
      state.addExerciseToSession(session, 'hip_thrust');
      state.restoreOrder(session, before);

      expect(idsOf(session), [...planned, 'hip_thrust']);
    });

    test('too little log to judge leaves everything alone', () async {
      final state = await legPressOnly(
        trackingSince: wednesday.subtract(const Duration(days: 5)),
      );
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      final planned = idsOf(session);

      expect(state.orderByNeed(session), isNull);
      expect(idsOf(session), planned);
      expect(state.laggingMusclesFor(session), isEmpty);
    });

    test('lagging muscles are the short ones today does nothing for', () async {
      final state = await legPressOnly();
      final session = state.startFromDay(dayNamed(state, 'Push Day'));

      final lagging = state.laggingMusclesFor(session);

      expect(
        [for (final l in lagging) l.volume.muscle],
        [MuscleGroup.back, MuscleGroup.biceps, MuscleGroup.hamstrings],
        reason: 'chest, shoulders, triceps and core are on the card already',
      );
      expect(
        [for (final l in lagging) l.suggestion.id],
        ['lat_pulldown', 'hammer_curl', 'lying_leg_curl'],
        reason: 'the plan\'s own choices, lightest to fit at the end first',
      );
    });

    test('a movement you already train is the one suggested', () async {
      final state = await legPressOnly();
      logSession(
        state,
        dayNamed(state, 'Pull Day'),
        exerciseId: 'incline_db_curl',
        sets: [(10.0, 10)],
      );

      expect(state.suggestionFor(MuscleGroup.biceps)!.id, 'incline_db_curl');
    });
  });

  group('session logging', () {
    test('starting a day builds one set entry per prescribed set', () async {
      final state = await seeded();
      final push = dayNamed(state, 'Push Day');
      final session = state.startFromDay(push);

      expect(session.exercises.length, push.activeItems.length);
      final bench = session.exercises.firstWhere(
        (e) => e.exerciseId == 'db_bench',
      );
      expect(bench.sets, hasLength(4));
      expect(bench.targetWeight, 7.5);
      expect(state.activeSession, same(session));
    });

    test('timed exercises prefill their target hold', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      final hang = state
          .startFromDay(pull)
          .exercises
          .firstWhere((e) => e.exerciseId == 'dead_hang');

      expect(hang.sets.first.durationSeconds, 30);
      expect(hang.repMax, 60);
    });

    test('a new session prefills from the last performance', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'hammer_curl',
        sets: [(10, 12), (10, 11)],
        rpe: 8,
      );

      final next = state
          .startFromDay(pull)
          .exercises
          .firstWhere((e) => e.exerciseId == 'hammer_curl');
      expect(next.sets.first.weight, 10);
      expect(next.sets.first.reps, 12);
      expect(next.sets.first.done, isFalse);
    });

    test('finishing drops unfinished sets and empty exercises', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      final press = session.exercises.firstWhere(
        (e) => e.exerciseId == 'leg_press',
      );
      state.updateSet(press.sets.first, weight: 50, reps: 15, done: true);

      expect(state.finishSession(session), isTrue);
      expect(state.activeSession, isNull);
      expect(session.exercises, hasLength(1));
      expect(session.exercises.first.sets, hasLength(1));
    });

    test('finishing with nothing logged discards the session', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      expect(state.finishSession(session), isFalse);
      expect(state.sessions, isEmpty);
    });

    test('session volume uses effective load, not the logged number', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'assisted_pullup',
        sets: [(55, 10)],
        rpe: 8,
      );

      // 80 kg bodyweight - 55 kg assistance = 25 kg, ten times.
      expect(state.finishedSessions.first.exercises.first.doneCount, 1);
      expect(state.sessionVolume(state.finishedSessions.first), 250);
    });

    test('RPE attaches to the last completed working set', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final curl = session.exercises.firstWhere(
        (e) => e.exerciseId == 'hammer_curl',
      );
      state.updateSet(curl.sets[0], weight: 7.5, reps: 12, done: true);
      state.updateSet(curl.sets[1], weight: 7.5, reps: 11, done: true);
      state.setLastSetRpe(curl, 9);

      expect(curl.sets[0].rpe, isNull);
      expect(curl.sets[1].rpe, 9);
    });
  });

  group('ticking a whole exercise', () {
    test('every remaining set is completed and blanks filled', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final assisted = session.exercises.firstWhere(
        (e) => e.exerciseId == 'assisted_pullup',
      );
      for (final set in assisted.sets) {
        state.updateSet(set, weight: 0, reps: 0);
      }

      final ticked = state.completeRemainingSets(assisted);

      expect(ticked, hasLength(4));
      expect(assisted.sets.every((s) => s.done), isTrue);
      expect(
        assisted.sets.every((s) => s.weight == 55),
        isTrue,
        reason: 'falls back to the planned load, as a single tap does',
      );
      expect(assisted.sets.every((s) => s.reps == 10), isTrue);
    });

    test('sets already logged are left exactly as they are', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      state.updateSet(pulldown.sets.first, weight: 30, reps: 15, done: true);

      final ticked = state.completeRemainingSets(pulldown);

      expect(ticked, hasLength(2), reason: 'only the untouched ones');
      expect(pulldown.sets.first.weight, 30, reason: 'not overwritten');
      expect(pulldown.sets.first.reps, 15);
    });

    test('it copies the previous session set by set', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 14), (24, 13)],
        rpe: 8,
      );

      final previous = state.lastPerformance('lat_pulldown');
      final session = state.startFromDay(pull);
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      for (final set in pulldown.sets) {
        state.updateSet(set, weight: 0, reps: 0);
      }

      state.completeRemainingSets(pulldown, previous: previous);

      expect(pulldown.sets.map((s) => s.reps), [15, 14, 13]);
    });

    test('timed and tempo work get their own fallbacks', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final hang = session.exercises.firstWhere(
        (e) => e.exerciseId == 'dead_hang',
      );
      final negatives = session.exercises.firstWhere(
        (e) => e.exerciseId == 'pullup_negative',
      );
      for (final set in hang.sets) {
        state.updateSet(set, durationSeconds: 0);
      }

      state.completeRemainingSets(hang);
      state.completeRemainingSets(negatives);

      expect(hang.sets.every((s) => s.durationSeconds == 30), isTrue);
      expect(
        negatives.sets.every((s) => s.tempoSeconds == defaultTempoSeconds),
        isTrue,
      );
    });

    test('undo puts them all back', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );

      final ticked = state.completeRemainingSets(pulldown);
      expect(pulldown.doneCount, 3);

      state.untickSets(ticked);
      expect(pulldown.doneCount, 0);
    });

    test('ticking nothing is a no-op', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final pulldown = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      state.completeRemainingSets(pulldown);

      expect(state.completeRemainingSets(pulldown), isEmpty);
    });
  });

  group('editing a finished session', () {
    test('a corrected weight flows through to the charts', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(240, 12)],
        rpe: 8,
      );

      expect(state.pointsFor('lat_pulldown').single.topWeight, 240);

      // The fat-finger fix: 240 was meant to be 24.
      final logged = state.finishedSessions.single.exercises.single;
      state.updateSet(logged.sets.single, weight: 24);

      expect(state.pointsFor('lat_pulldown').single.topWeight, 24);
      expect(state.personalRecord('lat_pulldown')!.topWeight, 24);
    });

    test('unticking a set drops it when editing ends', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 12), (24, 12), (24, 11)],
        rpe: 8,
      );

      final logged = state.finishedSessions.single.exercises.single;
      state.updateSet(logged.sets.last, done: false);

      expect(state.tidyFinishedSession(state.finishedSessions.single), isTrue);
      expect(logged.sets, hasLength(2));
    });

    test('an emptied exercise is removed with it', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      final session = state.startFromDay(legs);
      final press = session.exercises.firstWhere(
        (e) => e.exerciseId == 'leg_press',
      );
      final curl = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lying_leg_curl',
      );
      state.completeSet(press, press.sets.first);
      state.completeSet(curl, curl.sets.first);
      state.finishSession(session);
      expect(session.exercises, hasLength(2));

      state.updateSet(curl.sets.single, done: false);
      state.tidyFinishedSession(session);

      expect(session.exercises.map((e) => e.exerciseId), ['leg_press']);
    });

    test('emptying the whole thing deletes the session', () async {
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
      state.updateSet(session.exercises.single.sets.single, done: false);

      expect(state.tidyFinishedSession(session), isFalse);
      expect(state.finishedSessions, isEmpty);
    });

    test('tidying leaves a live session alone', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final before = session.exercises.length;

      expect(state.tidyFinishedSession(session), isTrue);
      expect(
        session.exercises,
        hasLength(before),
        reason: 'nothing is done yet, but the workout is still running',
      );
    });
  });

  group('quick-tap defaults', () {
    test('an untouched negative still records its descent time', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final neg = session.exercises.firstWhere(
        (e) => e.exerciseId == 'pullup_negative',
      );

      state.completeSet(neg, neg.sets.first);

      expect(neg.sets.first.done, isTrue);
      expect(neg.sets.first.reps, 5);
      expect(neg.sets.first.tempoSeconds, defaultTempoSeconds);
    });

    test('an untouched hold falls back to its target seconds', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final hang = session.exercises.firstWhere(
        (e) => e.exerciseId == 'dead_hang',
      );
      hang.sets.first.durationSeconds = 0;

      state.completeSet(hang, hang.sets.first);
      expect(hang.sets.first.durationSeconds, 30);
    });

    test('an untouched loaded set falls back to the planned weight', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final assisted = session.exercises.firstWhere(
        (e) => e.exerciseId == 'assisted_pullup',
      );
      assisted.sets.first.weight = 0;

      state.completeSet(assisted, assisted.sets.first);
      expect(assisted.sets.first.weight, 55);
      expect(assisted.sets.first.reps, 10);
    });

    test('the previous session wins over the fallback', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');

      final first = state.startFromDay(pull);
      final neg = first.exercises.firstWhere(
        (e) => e.exerciseId == 'pullup_negative',
      );
      first.exercises.removeWhere((e) => e.id != neg.id);
      for (final s in neg.sets) {
        state.updateSet(s, reps: 5, tempoSeconds: 4, done: true);
      }
      state.setLastSetRpe(neg, 8);
      state.finishSession(first);

      final second = state.startFromDay(pull);
      final next = second.exercises.firstWhere(
        (e) => e.exerciseId == 'pullup_negative',
      );
      expect(next.sets.first.tempoSeconds, 4);

      final added = SetEntry();
      next.sets.add(added);
      state.completeSet(next, added, previous: neg.sets.first);
      expect(added.tempoSeconds, 4);
    });

    test('logged descent time feeds the pull-up goal marker', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      final session = state.startFromDay(pull);
      final neg = session.exercises.firstWhere(
        (e) => e.exerciseId == 'pullup_negative',
      );
      session.exercises.removeWhere((e) => e.id != neg.id);
      for (final s in neg.sets) {
        state.updateSet(s, reps: 5, tempoSeconds: 5, done: true);
      }
      state.finishSession(session);

      final marker = state.primaryGoal!.markers.firstWhere(
        (m) => m.label == 'Negative duration',
      );
      final reading = state.readMarker(marker);

      expect(reading.current, 5);
      expect(reading.improved, isTrue, reason: 'baseline was the 2 s plateau');
    });
  });

  group('next session preview', () {
    test('it matches what starting the day actually does', () async {
      final state = await seeded();
      final day = dayNamed(state, 'Pull Day');
      logSession(
        state,
        day,
        exerciseId: 'lat_pulldown',
        sets: [(40, 12), (40, 12)],
        rpe: 7,
      );

      final preview = state.previewDay(day);
      final session = state.startFromDay(day);

      // The whole point: a preview that disagrees with the session it is
      // previewing is worse than none.
      expect(
        preview.map((p) => p.def.id),
        session.exercises.map((e) => e.exerciseId),
      );
      for (var i = 0; i < preview.length; i++) {
        expect(
          preview[i].opening.sets.map((s) => s.weight),
          session.exercises[i].sets.map((s) => s.weight),
        );
        expect(
          preview[i].opening.sets.map((s) => s.reps),
          session.exercises[i].sets.map((s) => s.reps),
        );
        expect(preview[i].steppedUp, session.exercises[i].autoProgressed);
      }
    });

    test('previewing starts nothing', () async {
      final state = await seeded();
      final before = state.sessions.length;

      state.previewDay(dayNamed(state, 'Pull Day'));

      expect(state.sessions, hasLength(before));
      expect(state.activeSession, isNull);
    });

    test('an earned increase shows as the load going up', () async {
      final state = await seeded();
      final day = dayNamed(state, 'Pull Day');
      // Every rep at the top of the 12-15 range, RPE 8: the one case that
      // earns more weight.
      logSession(
        state,
        day,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 15)],
        rpe: 8,
      );

      final row = state
          .previewDay(day)
          .firstWhere((p) => p.def.id == 'lat_pulldown');

      expect(row.steppedUp, isTrue);
      expect(row.openingLoad, greaterThan(24));
      expect(row.opening.previousLoad, 24);
      // A heavier bar resets the range.
      expect(row.opening.sets.first.reps, row.opening.repMin);
    });

    test('a lift never trained asks for a working weight', () async {
      final state = await seeded();
      final row = state
          .previewDay(dayNamed(state, 'Pull Day'))
          .firstWhere((p) => p.def.id == 'lat_pulldown');

      expect(row.steppedUp, isFalse);
      expect(
        row.advice.kind,
        anyOf(AdviceKind.establish, AdviceKind.firstTime),
      );
    });

    test('an opening under the range is flagged as climbing to it', () async {
      final state = await seeded();
      final day = dayNamed(state, 'Pull Day');
      // A 20 s hang against a printed 30-60 s: the next target steps to 25 s,
      // which is right but reads like a bug without the note.
      logSession(
        state,
        day,
        exerciseId: 'dead_hang',
        sets: [(0, 0)],
        durationSeconds: 20,
      );

      final row = state
          .previewDay(day)
          .firstWhere((p) => p.def.id == 'dead_hang');

      expect(row.opening.sets.first.durationSeconds, 25);
      expect(row.opening.repMin, 30);
      expect(
        row.opening.sets.first.durationSeconds,
        lessThan(row.opening.repMin),
      );
    });

    test('a routine with nothing active previews as empty', () async {
      final state = await seeded();
      final day = dayNamed(state, 'Pull Day');
      for (final item in [...day.items]) {
        state.updatePlanItem(item, active: false);
      }

      expect(state.previewDay(day), isEmpty);
    });
  });

  group('reordering a session', () {
    test('a waiting exercise can be pulled to the front', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final wanted = session.exercises[3];
      final count = session.exercises.length;

      state.doExerciseNext(session, wanted);

      expect(session.exercises.first.id, wanted.id);
      expect(session.exercises, hasLength(count), reason: 'moved, not copied');
    });

    test(
      'it lands behind work already under way, not in front of it',
      () async {
        final state = await seeded();
        final session = state.startFromDay(dayNamed(state, 'Pull Day'));
        // First two exercises have been started.
        state.updateSet(session.exercises[0].sets.first, done: true);
        state.updateSet(session.exercises[1].sets.first, done: true);
        final wanted = session.exercises[4];

        state.doExerciseNext(session, wanted);

        // Third: right after the two that happened, not ahead of them.
        expect(session.exercises[2].id, wanted.id);
        expect(session.exercises[0].doneCount, 1);
        expect(session.exercises[1].doneCount, 1);
      },
    );

    test('an exercise already under way is left where it is', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      state.updateSet(session.exercises[0].sets.first, done: true);
      final started = session.exercises[0];

      // Moving it would rewrite the order things actually happened in.
      state.doExerciseNext(session, started);

      expect(session.exercises.first.id, started.id);
    });

    test('one can be put off to the end instead', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final skipped = session.exercises[1];
      final count = session.exercises.length;

      state.doExerciseLater(session, skipped);

      expect(session.exercises.last.id, skipped.id);
      expect(session.exercises, hasLength(count), reason: 'moved, not copied');
    });

    test('moving the last one later changes nothing', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final before = [for (final e in session.exercises) e.id];

      state.doExerciseLater(session, session.exercises.last);

      expect([for (final e in session.exercises) e.id], before);
    });
  });

  group('finish summary', () {
    /// Finishes a one-exercise session at [load], counting anything left
    /// unticked the way the finish dialog does.
    SessionSummary finish(AppState state, double load, {int extraSets = 0}) {
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final se = session.exercises.firstWhere(
        (e) => e.exerciseId == 'lat_pulldown',
      );
      session.exercises.removeWhere((e) => e.id != se.id);
      se.sets.removeRange(1, se.sets.length);
      for (var i = 0; i < extraSets; i++) {
        state.addSet(se);
      }
      state.updateSet(se.sets.first, weight: load, reps: 10, done: true);
      state.setLastSetRpe(se, 8);

      final dropped = session.totalSets - session.doneSets;
      state.finishSession(session);
      return state.summarise(session, droppedSets: dropped);
    }

    test('it reads the workout back rather than being told', () async {
      final state = await seeded();
      final summary = finish(state, 40);

      expect(summary.title, isNotEmpty);
      expect(summary.sets, 1);
      expect(summary.volume, 400);
      expect(summary.cleanSweep, isTrue);
    });

    test('a first-ever session is a record with nothing to beat', () async {
      final state = await seeded();
      final summary = finish(state, 40);

      expect(summary.records, hasLength(1));
      expect(summary.records.first.def.id, 'lat_pulldown');
      expect(summary.records.first.previousBest, isNull);
      expect(summary.fanfare, 3);
      expect(summary.headline, 'A new best');
    });

    test('beating an old best names what it beat', () async {
      final state = await seeded();
      finish(state, 40);
      final summary = finish(state, 50);

      expect(summary.records, hasLength(1));
      expect(summary.records.first.previousBest, isNotNull);
      expect(
        summary.records.first.score,
        greaterThan(summary.records.first.previousBest!),
      );
    });

    test('a session that beats nothing is still worth finishing', () async {
      final state = await seeded();
      finish(state, 50);
      final summary = finish(state, 40);

      expect(summary.records, isEmpty);
      // Everything planned was done, so it lands in the middle tier.
      expect(summary.fanfare, 2);
      expect(summary.headline, 'Every set done');
    });

    test('sets left undone are counted and drop the fanfare', () async {
      final state = await seeded();
      finish(state, 50);
      final summary = finish(state, 40, extraSets: 2);

      expect(summary.droppedSets, 2);
      expect(summary.cleanSweep, isFalse);
      expect(summary.fanfare, 1);
      expect(summary.headline, 'Session logged');
    });

    test('a record outranks unfinished sets', () async {
      final state = await seeded();
      final summary = finish(state, 60, extraSets: 2);

      // A best is a best even on a session you cut short.
      expect(summary.records, hasLength(1));
      expect(summary.cleanSweep, isFalse);
      expect(summary.fanfare, 3);
    });

    test('the week streak comes along', () async {
      final state = await seeded();
      final summary = finish(state, 40);

      expect(summary.weekStreak, greaterThanOrEqualTo(1));
    });

    test('so does the energy estimate', () async {
      final state = await seeded();
      final summary = finish(state, 40);

      // One set of 10 reps at 3 s plus its 90 s rest is two minutes, and
      // 5 METs x 3.5 ml/kg/min x 80 kg / 200 x 2 min is 14 kcal.
      expect(summary.calories, closeTo(14, 0.001));
    });
  });

  group('warm-ups on the card', () {
    test('the ramp goes in front and earns no volume', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      final se = session.exercises.firstWhere(
        (e) => warmupWorthwhile(state.exerciseById(e.exerciseId)),
      );
      for (final set in se.sets) {
        state.updateSet(set, weight: 100);
      }
      final workingSets = se.sets.length;

      final added = state.addWarmupSets(se, state.warmupFor(se));
      expect(added, isNotEmpty);
      expect(se.sets.length, workingSets + added.length);
      // Ahead of the working sets, in the order they are done.
      expect(se.sets.take(added.length).every((s) => s.warmup), isTrue);

      for (final set in added) {
        state.updateSet(set, done: true);
      }
      // Ticked off and still worth nothing: warm-ups are not training volume.
      expect(state.exerciseVolume(session, se), 0);
      expect(se.workingSets, isEmpty);
    });

    test('the working load comes from the heaviest working set', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      final se = session.exercises.first;

      state.updateSet(se.sets.first, weight: 90);
      expect(state.workingLoadOf(se), greaterThanOrEqualTo(90));
    });

    test('undo takes the whole ramp back out', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      final se = session.exercises.firstWhere(
        (e) => warmupWorthwhile(state.exerciseById(e.exerciseId)),
      );
      state.updateSet(se.sets.first, weight: 100);
      final before = se.sets.length;

      final added = state.addWarmupSets(se, state.warmupFor(se));
      expect(added, isNotEmpty);

      state.removeSets(se, added);
      expect(se.sets.length, before);
      expect(se.sets.any((s) => s.warmup), isFalse);
    });

    test('a warm-up left untouched is dropped when the session ends', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Leg Day'));
      final se = session.exercises.firstWhere(
        (e) => warmupWorthwhile(state.exerciseById(e.exerciseId)),
      );
      state.updateSet(se.sets.first, weight: 100);

      expect(state.addWarmupSets(se, state.warmupFor(se)), isNotEmpty);
      state.updateSet(se.sets.last, done: true);
      state.finishSession(session);

      final logged = state.finishedSessions.first.exercises.firstWhere(
        (e) => e.exerciseId == se.exerciseId,
      );
      expect(logged.sets.any((s) => s.warmup), isFalse);
    });
  });

  group('undoing a delete', () {
    test('a set goes back where it was, with its numbers', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      final plank = session.exercises.firstWhere(
        (e) => e.exerciseId == 'plank',
      );
      final middle = plank.sets[1]..durationSeconds = 42;

      state.removeSet(plank, middle.id);
      expect(plank.sets, hasLength(2));

      state.insertSet(plank, 1, middle);

      expect(plank.sets, hasLength(3));
      expect(plank.sets[1].id, middle.id);
      expect(plank.sets[1].durationSeconds, 42);
    });

    test('undoing twice does not duplicate the set', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      final plank = session.exercises.firstWhere(
        (e) => e.exerciseId == 'plank',
      );
      final first = plank.sets.first;

      state.removeSet(plank, first.id);
      state.insertSet(plank, 0, first);
      state.insertSet(plank, 0, first);

      expect(plank.sets.where((x) => x.id == first.id), hasLength(1));
    });

    test('a restored set past the end lands at the end', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Push Day'));
      final plank = session.exercises.firstWhere(
        (e) => e.exerciseId == 'plank',
      );
      final last = plank.sets.last;

      state.removeSet(plank, last.id);
      state.insertSet(plank, 99, last);

      expect(plank.sets.last.id, last.id);
    });

    test('a deleted workout comes back in date order', () async {
      final state = await seededOn(DateTime(2026, 9, 2));
      logOn(state, DateTime(2026, 8, 31), dayNamed(state, 'Pull Day'));
      logOn(state, DateTime(2026, 9, 1), dayNamed(state, 'Push Day'));
      final older = state.finishedSessions.last;

      state.deleteSession(older.id);
      expect(state.finishedSessions, hasLength(1));

      state.restoreSession(older);

      expect(state.finishedSessions, hasLength(2));
      expect(
        state.finishedSessions.last.id,
        older.id,
        reason: 'newest first, so the older one sorts back to the end',
      );
      state.restoreSession(older);
      expect(state.finishedSessions, hasLength(2), reason: 'no duplicate');
    });

    test('a restored weigh-in brings the working bodyweight with it', () async {
      final state = await seededOn(DateTime(2026, 9, 2));
      state.logBodyweight(80, date: DateTime(2026, 8, 20));
      state.logBodyweight(77, date: DateTime(2026, 9, 1));
      final latest = state.bodyweights.first;
      expect(state.currentBodyweight, closeTo(77, 0.01));

      state.deleteBodyweight(latest.id);
      expect(state.currentBodyweight, closeTo(80, 0.01));

      state.restoreBodyweight(latest);

      expect(state.bodyweights, hasLength(2));
      expect(state.bodyweights.first.id, latest.id, reason: 'newest first');
      expect(state.currentBodyweight, closeTo(77, 0.01));
      expect(state.settings.bodyweightKg, closeTo(77, 0.01));
    });
  });
}
