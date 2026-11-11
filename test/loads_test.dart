import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/data/progression.dart';
import 'package:gym_tracker/models/models.dart';
import 'package:gym_tracker/utils/plates.dart';

import 'helpers.dart';

void main() {
  group('plate calculator', () {
    const plates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];

    test('splits an exact load evenly across both sides', () {
      final r = calculatePlates(target: 100, barWeight: 20, available: plates);
      expect(r.exact, isTrue);
      expect(r.achieved, 100);
      expect(r.perSide.map((s) => '${s.count}x${s.plate}').toList(), [
        '1x25.0',
        '1x15.0',
      ]);
    });

    test(
      'reports the closest loadable weight when it cannot hit the target',
      () {
        final r = calculatePlates(
          target: 101,
          barWeight: 20,
          available: plates,
        );
        expect(r.exact, isFalse);
        expect(r.achieved, 100);
        expect(r.leftover, closeTo(1, 0.001));
      },
    );

    test('flags targets lighter than the bar', () {
      final r = calculatePlates(target: 15, barWeight: 20, available: plates);
      expect(r.belowBar, isTrue);
      expect(r.perSide, isEmpty);
    });
  });

  group('effective load', () {
    ExerciseDef def({
      LoadSemantics semantics = LoadSemantics.normal,
      bool perSide = false,
      double? base,
      TrackingMode tracking = TrackingMode.weightReps,
    }) => ExerciseDef(
      name: 'X',
      loadSemantics: semantics,
      loadIsPerSide: perSide,
      baseLoadKg: base,
      tracking: tracking,
    );

    test('doubles a per-side dumbbell load', () {
      final set = SetEntry(weight: 7.5, reps: 10, done: true);
      expect(effectiveLoad(def(perSide: true), set, 80), 15);
    });

    test('a machine base load is already inside the logged number', () {
      final set = SetEntry(weight: 50, reps: 12, done: true);
      // 50 kg on the leg press is 50 kg of resistance: the total is read off
      // the machine with the sled included. Adding the sled on top would count
      // it twice and inflate every volume and e1RM figure for the lift.
      expect(effectiveLoad(def(base: 40), set, 80), 50);
    });

    test('the plate calculator and the load maths agree', () {
      final legPress = ExerciseDef(
        name: 'Leg press',
        equipment: Equipment.machinePlateLoaded,
        baseLoadKg: 40,
      );
      final plates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
      // The machine reads 140, of which 40 kg is the sled.
      final set = SetEntry(weight: 140, reps: 8, done: true);

      final loaded = calculatePlates(
        target: set.weight,
        barWeight: 40,
        available: plates,
      );

      // What the sheet tells you to hang on, sled included, has to be the
      // resistance the log credits you with. These two drifting apart is what
      // made the leg press read 40 kg heavier than it was.
      expect(loaded.exact, isTrue);
      expect(loaded.achieved, 140);
      expect(effectiveLoad(legPress, set, 80), loaded.achieved);
    });

    test('assistance is inverted — bodyweight minus the help', () {
      final set = SetEntry(weight: 55, reps: 10, done: true);
      final d = def(semantics: LoadSemantics.assistanceInverted);
      expect(effectiveLoad(d, set, 80), 25);
      expect(setVolume(d, set, 80), 250);
    });

    test('dropping assistance raises the effective load', () {
      final d = def(semantics: LoadSemantics.assistanceInverted);
      final before = SetEntry(weight: 55, reps: 10, done: true);
      final after = SetEntry(weight: 40, reps: 10, done: true);
      expect(
        effectiveLoad(d, after, 80),
        greaterThan(effectiveLoad(d, before, 80)),
      );
    });

    test('bodyweight movements carry bodyweight', () {
      final set = SetEntry(weight: 0, reps: 8, done: true);
      final d = def(
        semantics: LoadSemantics.bodyweightOnly,
        tracking: TrackingMode.bodyweightReps,
      );
      expect(effectiveLoad(d, set, 80), 80);
      expect(setVolume(d, set, 80), 640);
    });

    test('timed holds contribute no rep volume', () {
      final set = SetEntry(durationSeconds: 45, done: true);
      final d = def(
        semantics: LoadSemantics.bodyweightOnly,
        tracking: TrackingMode.duration,
      );
      expect(setVolume(d, set, 80), 0);
      expect(setScore(d, set, 80), 45);
    });

    test('unfinished and warm-up sets never count', () {
      final d = def();
      expect(setVolume(d, SetEntry(weight: 50, reps: 10), 80), 0);
      expect(
        setVolume(
          d,
          SetEntry(weight: 50, reps: 10, done: true, warmup: true),
          80,
        ),
        0,
      );
    });
  });

  group('bodyweight movements with added load', () {
    test('what you hold rides on top of your bodyweight', () async {
      final state = await seeded();
      final def = state.exerciseById('bulgarian_split_squat');

      expect(def.loadSemantics, LoadSemantics.bodyweightOnly);
      expect(
        def.tracking,
        TrackingMode.weightReps,
        reason: 'there has to be somewhere to log the dumbbells',
      );

      expect(
        effectiveLoad(def, SetEntry(weight: 0, reps: 10), 80),
        80,
        reason: 'bodyweight only, which is where it starts',
      );
      expect(effectiveLoad(def, SetEntry(weight: 12, reps: 10), 80), 92);
    });

    test('per-side load counts both hands', () async {
      final state = await seeded();
      final def = state.exerciseById('bulgarian_split_squat')
        ..loadIsPerSide = true;

      expect(
        effectiveLoad(def, SetEntry(weight: 10, reps: 8), 80),
        100,
        reason: 'a dumbbell in each hand is twice the logged number',
      );
    });

    test('volume counts the bodyweight, not just the dumbbells', () async {
      final state = await seeded();
      final def = state.exerciseById('bulgarian_split_squat');
      final set = SetEntry(weight: 10, reps: 10, done: true);

      expect(setVolume(def, set, 80), 900);
    });

    /// An install seeded when the split squat was still reps-only, with a
    /// workout already logged against that version.
    Future<({AppState state, WorkoutSession logged, double volume})>
    repsOnlyInstall({void Function(Map)? edit}) async {
      final original = await seeded();
      logSession(
        original,
        dayNamed(original, 'Leg Day'),
        exerciseId: 'bulgarian_split_squat',
        sets: [(0, 10), (0, 10), (0, 10)],
      );
      final json = original.toJson();
      for (final e in (json['exercises'] as List)) {
        if ((e as Map)['id'] != 'bulgarian_split_squat') continue;
        e['tracking'] = TrackingMode.bodyweightReps.name;
        e['equipment'] = Equipment.bodyweight.name;
        e['incrementKg'] = null;
        edit?.call(e);
      }
      final state = AppState(storage: MemoryStorage()..data = json);
      await state.load();
      return (
        state: state,
        logged: original.sessions.first,
        volume: original.sessionVolume(original.sessions.first),
      );
    }

    test(
      'a reps-only split squat from an older install can take weight',
      () async {
        final old = await repsOnlyInstall(
          edit: (e) => e['name'] = 'Split squat, my name',
        );
        final def = old.state.exerciseById('bulgarian_split_squat');

        expect(
          def.tracking,
          TrackingMode.weightReps,
          reason: 'there has to be somewhere to log the dumbbells',
        );
        expect(def.loadSemantics, LoadSemantics.bodyweightOnly);
        expect(def.equipment, Equipment.dumbbell);
        expect(def.incrementKg, 2.5);
        expect(
          def.name,
          'Split squat, my name',
          reason: 'only the missing weight column is repaired',
        );

        final logged = old.state.sessions.firstWhere(
          (s) => s.id == old.logged.id,
        );
        expect(
          old.state.sessionVolume(logged),
          old.volume,
          reason: 'old sets were bodyweight only, and still count as that',
        );
      },
    );

    test('a step chosen by hand survives the repair', () async {
      final old = await repsOnlyInstall(edit: (e) => e['incrementKg'] = 2);
      expect(old.state.exerciseById('bulgarian_split_squat').incrementKg, 2);
    });

    test('movements that ship reps-only stay reps-only', () async {
      final state = await seeded();
      final again = AppState(storage: MemoryStorage()..data = state.toJson());
      await again.load();

      expect(
        again.exerciseById('pushup').tracking,
        TrackingMode.bodyweightReps,
      );
      expect(again.exerciseById('pushup').equipment, Equipment.bodyweight);
    });
  });
}
