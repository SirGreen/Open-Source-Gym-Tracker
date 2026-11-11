import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/data/progression.dart';
import 'package:gym_tracker/models/models.dart';
import 'package:gym_tracker/utils/plates.dart';

import 'helpers.dart';

void main() {
  group('progression rules', () {
    test('all reps at the top with RPE 8 earns a load increase', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 12), (24, 12), (24, 12)],
        rpe: 8,
      );

      final advice = state.adviceFor('lat_pulldown', 12);
      expect(advice.kind, AdviceKind.increase);
      expect(advice.suggestedLoad, 30); // 24 + the 6 kg stack step
    });

    test('assistance machines progress downward', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'assisted_pullup',
        sets: [(55, 10), (55, 10), (55, 10), (55, 10)],
        rpe: 7,
      );

      final advice = state.adviceFor('assisted_pullup', 10);
      expect(advice.kind, AdviceKind.increase);
      expect(advice.suggestedLoad, 50);
      expect(advice.message, contains('Drop assistance'));
    });

    test('reps short of the target means chase reps, not weight', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 12), (24, 10), (24, 9)],
        rpe: 7,
      );

      final advice = state.adviceFor('lat_pulldown', 12);
      expect(advice.kind, AdviceKind.addReps);
      expect(advice.message, contains('9'));
    });

    test('completing all reps is not enough without an RPE', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 12), (24, 12), (24, 12)],
      );

      expect(state.adviceFor('lat_pulldown', 12).kind, AdviceKind.needsRpe);
    });

    test('RPE 9 holds the weight, RPE 10 backs off', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');

      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 12), (24, 12), (24, 12)],
        rpe: 9,
      );
      expect(state.adviceFor('lat_pulldown', 12).kind, AdviceKind.hold);

      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 12), (24, 12), (24, 12)],
        rpe: 10,
      );
      expect(state.adviceFor('lat_pulldown', 12).kind, AdviceKind.reduce);
    });

    test('warns when the machine step is a big percentage jump', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      logSession(
        state,
        legs,
        exerciseId: 'leg_extension',
        sets: [(22.5, 15), (22.5, 15), (22.5, 15), (22.5, 15)],
        rpe: 7,
      );

      final advice = state.adviceFor('leg_extension', 15);
      expect(advice.kind, AdviceKind.increase);
      expect(advice.suggestedLoad, 27);
      expect(advice.message, contains('20%'));
    });

    test('three easy sessions at the same load raise a stale flag', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      for (var i = 0; i < 3; i++) {
        logSession(
          state,
          pull,
          exerciseId: 'lat_pulldown',
          sets: [(24, 11), (24, 11), (24, 11)],
          rpe: 7,
        );
      }

      final advice = state.adviceFor('lat_pulldown', 12);
      expect(advice.kind, AdviceKind.stale);
      expect(advice.message, contains('24 kg'));
    });

    test('an unestablished working weight asks for one', () async {
      final state = await seeded();
      expect(state.adviceFor('pec_deck', 15).kind, AdviceKind.establish);
    });
  });

  group('rep progression', () {
    test('the target steps one rep and clamps at the ceiling', () {
      expect(nextTarget(null, 10, 13, repStep), 10, reason: 'no history');
      expect(nextTarget(10, 10, 13, repStep), 11);
      expect(nextTarget(12, 10, 13, repStep), 13);
      expect(nextTarget(13, 10, 13, repStep), 13, reason: 'holds at the top');
      expect(nextTarget(20, 10, 13, repStep), 13, reason: 'overshoot clamps');
    });

    test('timed holds climb five seconds at a time', () {
      expect(nextTarget(30, 30, 60, durationStepSeconds), 35);
      expect(nextTarget(58, 30, 60, durationStepSeconds), 60);
    });

    test('the next session asks for one more rep than last time', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 12), (24, 12), (24, 12)],
        rpe: 8,
      );

      final next = state
          .startFromDay(pull)
          .exercises
          .firstWhere((e) => e.exerciseId == 'lat_pulldown');

      expect(next.repMax, 15, reason: 'doc number is the floor now');
      expect(next.sets.first.reps, 13);
    });

    test('a hold prefills five seconds longer', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'dead_hang',
        sets: [(0, 0)],
        durationSeconds: 30,
      );

      final next = state
          .startFromDay(pull)
          .exercises
          .firstWhere((e) => e.exerciseId == 'dead_hang');
      expect(next.sets.first.durationSeconds, 35);
    });

    test('with auto-progression off the target holds at the ceiling', () async {
      final state = await seeded();
      state.updateSettings(autoProgress: false);
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 15)],
        rpe: 8,
      );

      final next = state
          .startFromDay(pull)
          .exercises
          .firstWhere((e) => e.exerciseId == 'lat_pulldown');
      expect(next.autoProgressed, isFalse);
      expect(next.sets.first.weight, 24);
      expect(next.sets.first.reps, 15, reason: 'no target beyond the ceiling');

      final advice = state.adviceFor('lat_pulldown', 15);
      expect(advice.kind, AdviceKind.increase);
      expect(advice.suggestedLoad, 30);
    });

    test('only the two doc-pinned exercises keep a fixed rep number', () async {
      final state = await seeded();
      final pinned = [
        for (final day in state.plan.days)
          for (final item in day.items)
            if (item.repMin == item.repMax) item.exerciseId,
      ];

      // Negatives progress by descent time, and the doc names its own trigger
      // for assisted pull-ups: "drop to 50 kg when 4x10 stops being a fight".
      expect(pinned, unorderedEquals(['pullup_negative', 'assisted_pullup']));
    });

    test("assisted pull-ups keep the doc's own trigger", () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      final item = pull.items.firstWhere(
        (i) => i.exerciseId == 'assisted_pullup',
      );
      logSession(
        state,
        pull,
        exerciseId: 'assisted_pullup',
        sets: [(55, 10), (55, 10), (55, 10), (55, 10)],
        rpe: 8,
      );

      final advice = state.adviceFor('assisted_pullup', item.repMax);
      expect(advice.kind, AdviceKind.increase);
      expect(advice.suggestedLoad, 50);
    });
  });

  group('automatic progression', () {
    int streakFor(AppState state, String exerciseId, int repMax) =>
        qualifyingStreak(
          def: state.exerciseById(exerciseId),
          history: state.historyOf(exerciseId),
          repMax: repMax,
        );

    test('the streak counts consecutive qualifying sessions', () async {
      final state = await seeded();
      state.updateSettings(autoProgress: false); // hold the load steady
      final pull = dayNamed(state, 'Pull Day');

      for (var i = 0; i < 2; i++) {
        logSession(
          state,
          pull,
          exerciseId: 'lat_pulldown',
          sets: [(24, 15), (24, 15), (24, 15)],
          rpe: 8,
        );
      }

      expect(streakFor(state, 'lat_pulldown', 15), 2);
    });

    test('a hard last set restarts the streak', () async {
      final state = await seeded();
      state.updateSettings(autoProgress: false);
      final pull = dayNamed(state, 'Pull Day');

      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 15)],
        rpe: 8,
      );
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 15)],
        rpe: 9,
      );

      expect(streakFor(state, 'lat_pulldown', 15), 0);
    });

    test('a missed rep restarts the streak', () async {
      final state = await seeded();
      state.updateSettings(autoProgress: false);
      final pull = dayNamed(state, 'Pull Day');

      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 15)],
        rpe: 8,
      );
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 14)],
        rpe: 8,
      );

      expect(streakFor(state, 'lat_pulldown', 15), 0);
    });

    test('a change of load restarts the streak', () async {
      final state = await seeded();
      state.updateSettings(autoProgress: false);
      final pull = dayNamed(state, 'Pull Day');

      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 15)],
        rpe: 8,
      );
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(30, 15), (30, 15), (30, 15)],
        rpe: 8,
      );

      expect(streakFor(state, 'lat_pulldown', 15), 1);
    });

    test('the next session opens at the new load with reps reset', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 15)],
        rpe: 8,
      );

      final next = state
          .startFromDay(pull)
          .exercises
          .firstWhere((e) => e.exerciseId == 'lat_pulldown');

      expect(next.autoProgressed, isTrue);
      expect(next.previousLoad, 24);
      expect(next.sets.every((s) => s.weight == 30), isTrue);
      expect(next.sets.first.reps, 12, reason: 'range resets to the floor');
    });

    test('assistance steps down on its own', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'assisted_pullup',
        sets: [(55, 10), (55, 10), (55, 10), (55, 10)],
        rpe: 8,
      );

      final next = state
          .startFromDay(pull)
          .exercises
          .firstWhere((e) => e.exerciseId == 'assisted_pullup');

      expect(next.autoProgressed, isTrue);
      expect(next.sets.first.weight, 50, reason: 'less help, not more weight');
    });

    test('requiring two sessions waits for the second', () async {
      final state = await seeded();
      state.updateSettings(autoProgressSessions: 2);
      final pull = dayNamed(state, 'Pull Day');

      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 15)],
        rpe: 8,
      );

      expect(state.adviceFor('lat_pulldown', 15).kind, AdviceKind.confirming);
      var next = state
          .startFromDay(pull)
          .exercises
          .firstWhere((e) => e.exerciseId == 'lat_pulldown');
      expect(next.autoProgressed, isFalse);
      expect(next.sets.first.weight, 24);
      state.discardSession(state.activeSession!);

      logSession(
        state,
        pull,
        exerciseId: 'lat_pulldown',
        sets: [(24, 15), (24, 15), (24, 15)],
        rpe: 8,
      );

      expect(state.adviceFor('lat_pulldown', 15).kind, AdviceKind.increase);
      next = state
          .startFromDay(pull)
          .exercises
          .firstWhere((e) => e.exerciseId == 'lat_pulldown');
      expect(next.autoProgressed, isTrue);
      expect(next.sets.first.weight, 30);
    });

    test('an unknown machine step is never invented', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      logSession(
        state,
        legs,
        exerciseId: 'hip_abductor',
        sets: [(40, 18), (40, 18), (40, 18), (40, 18)],
        rpe: 7,
      );

      final advice = state.adviceFor('hip_abductor', 18);
      expect(advice.kind, AdviceKind.needsIncrement);
      expect(advice.suggestedLoad, isNull);

      final next = state
          .startFromDay(legs)
          .exercises
          .firstWhere((e) => e.exerciseId == 'hip_abductor');
      expect(next.autoProgressed, isFalse);
      expect(next.sets.first.weight, 40);
    });

    test('a machine step recorded later is used from then on', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      logSession(
        state,
        legs,
        exerciseId: 'hip_abductor',
        sets: [(40, 18), (40, 18), (40, 18), (40, 18)],
        rpe: 7,
      );
      final def = state.exerciseById('hip_abductor');

      state.updateExercise(def, incrementKg: 0);
      expect(def.incrementKg, isNull, reason: 'a step of nothing is no step');

      state.updateExercise(def, incrementKg: 5);
      final advice = state.adviceFor('hip_abductor', 18);
      expect(advice.kind, AdviceKind.increase);
      expect(advice.suggestedLoad, 45);

      final next = state
          .startFromDay(legs)
          .exercises
          .firstWhere((e) => e.exerciseId == 'hip_abductor');
      expect(next.autoProgressed, isTrue);
      expect(next.sets.first.weight, 45);
    });

    test('the settings survive a backup round-trip', () async {
      final state = await seeded();
      state.updateSettings(autoProgress: false, autoProgressSessions: 3);

      final restored = AppState(storage: MemoryStorage())
        ..importFrom(state.toJson());
      expect(restored.settings.autoProgress, isFalse);
      expect(restored.settings.autoProgressSessions, 3);
    });
  });

  group('warm-up ramp', () {
    final plates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

    ExerciseDef barbell({double barWeight = 20}) => ExerciseDef(
      name: 'Barbell bench press',
      equipment: Equipment.barbell,
      effortClass: EffortClass.heavyCompound,
      barWeight: barWeight,
    );

    test('ramps up to the working weight, never past it', () {
      final ramp = warmupRamp(def: barbell(), workingLoad: 100, plates: plates);

      expect(ramp.length, 3);
      expect(ramp.map((w) => w.weight), [40, 60, 80]);
      // Reps come down as the load goes up: preparation, not work.
      expect(ramp.map((w) => w.reps), [8, 5, 3]);
      for (final set in ramp) {
        expect(set.weight, lessThan(100));
      }
    });

    test('every step is something the plates can actually make', () {
      final ramp = warmupRamp(
        def: barbell(),
        workingLoad: 102.5,
        plates: plates,
      );

      for (final set in ramp) {
        final made = calculatePlates(
          target: set.weight,
          barWeight: 20,
          available: plates,
        );
        expect(made.exact, isTrue, reason: '${set.weight} kg is not loadable');
      }
    });

    test('steps at or under the empty bar are dropped', () {
      // 40% of 45 kg is 18 kg — under the bar, so there is nothing to load.
      final ramp = warmupRamp(def: barbell(), workingLoad: 45, plates: plates);

      expect(ramp, isNotEmpty);
      for (final set in ramp) {
        expect(set.weight, greaterThan(20));
      }
    });

    test('a working load at the bar has nothing to ramp', () {
      expect(
        warmupRamp(def: barbell(), workingLoad: 20, plates: plates),
        isEmpty,
      );
    });

    test('two steps that snap to the same bar are not repeated', () {
      final ramp = warmupRamp(
        def: barbell(barWeight: 20),
        workingLoad: 30,
        plates: plates,
      );

      final weights = ramp.map((w) => w.weight).toList();
      expect(weights.toSet().length, weights.length);
    });

    test('a machine base load rides under every step', () {
      final legPress = ExerciseDef(
        name: 'Leg press',
        equipment: Equipment.machinePlateLoaded,
        effortClass: EffortClass.heavyCompound,
        baseLoadKg: 40,
      );
      final ramp = warmupRamp(def: legPress, workingLoad: 160, plates: plates);

      expect(ramp, isNotEmpty);
      for (final set in ramp) {
        // The sled rides under every step, so the real resistance is always
        // above it however few plates go on.
        final resistance = effectiveLoad(
          legPress,
          SetEntry(weight: set.weight),
          0,
        );
        // Heavier than the bare sled, lighter than the working set.
        expect(resistance, greaterThan(40));
        expect(resistance, lessThan(160));
      }
    });

    test('an assistance machine warms up with more help, not less', () {
      final assisted = ExerciseDef(
        name: 'Assisted pull-up',
        equipment: Equipment.assisted,
        loadSemantics: LoadSemantics.assistanceInverted,
        effortClass: EffortClass.heavyCompound,
        incrementKg: 5,
      );
      // 80 kg bodyweight, 30 kg of help: 50 kg of real pull.
      final ramp = warmupRamp(
        def: assisted,
        workingLoad: 30,
        plates: plates,
        bodyweightKg: 80,
      );

      expect(ramp, isNotEmpty);
      for (final set in ramp) {
        // More assistance than the working set — a higher logged number.
        expect(set.weight, greaterThan(30));
        expect(
          effectiveLoad(assisted, SetEntry(weight: set.weight), 80),
          lessThan(50),
        );
      }
      // And it still gets harder as it goes.
      expect(ramp.first.weight, greaterThan(ramp.last.weight));
    });

    test('an unknown machine step is rounded, never invented', () {
      final machine = ExerciseDef(
        name: 'Chest press',
        equipment: Equipment.machineStack,
        effortClass: EffortClass.moderateCompound,
      );
      final ramp = warmupRamp(def: machine, workingLoad: 47, plates: plates);

      expect(ramp.map((w) => w.weight), [18.8, 28.2, 37.6]);
    });

    test('a known stack step is respected', () {
      final machine = ExerciseDef(
        name: 'Chest press',
        equipment: Equipment.machineStack,
        effortClass: EffortClass.moderateCompound,
        incrementKg: 5,
      );
      final ramp = warmupRamp(def: machine, workingLoad: 50, plates: plates);

      for (final set in ramp) {
        expect(set.weight % 5, 0);
      }
    });

    test('nothing loaded by weight gets no ramp', () {
      for (final tracking in [
        TrackingMode.bodyweightReps,
        TrackingMode.duration,
        TrackingMode.tempoReps,
      ]) {
        final def = ExerciseDef(
          name: 'Pull-up',
          tracking: tracking,
          effortClass: EffortClass.heavyCompound,
        );
        expect(
          warmupRamp(def: def, workingLoad: 10, plates: plates),
          isEmpty,
          reason: '$tracking should not ramp by load',
        );
      }
    });

    test('isolation work is not worth a ramp', () {
      expect(warmupWorthwhile(barbell()), isTrue);
      expect(
        warmupWorthwhile(
          ExerciseDef(
            name: 'Lateral raise',
            effortClass: EffortClass.isolation,
          ),
        ),
        isFalse,
      );
      expect(
        warmupWorthwhile(
          ExerciseDef(
            name: 'Plank',
            tracking: TrackingMode.duration,
            effortClass: EffortClass.heavyCompound,
          ),
        ),
        isFalse,
      );
    });
  });
}
