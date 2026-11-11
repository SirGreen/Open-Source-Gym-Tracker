import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/data/progression.dart';
import 'package:gym_tracker/models/models.dart';

import 'helpers.dart';

void main() {
  group('seeded plan', () {
    test('every plan item points at a real exercise', () async {
      final state = await seeded();
      final ids = state.exercises.map((e) => e.id).toSet();
      for (final day in state.plan.days) {
        for (final item in day.items) {
          expect(
            ids,
            contains(item.exerciseId),
            reason: '${day.name} references ${item.exerciseId}',
          );
        }
      }
    });

    test('every routine points at real goals', () async {
      final state = await seeded();
      final goalIds = state.goals.map((g) => g.id).toSet();
      for (final day in state.plan.days) {
        for (final id in day.goalIds) {
          expect(goalIds, contains(id));
        }
      }
    });

    test('pull runs twice a week and rest days are empty', () async {
      final state = await seeded();
      expect(
        state.plan.daysForWeekday(DateTime.monday).single.name,
        'Pull Day',
      );
      expect(
        state.plan.daysForWeekday(DateTime.friday).single.name,
        'Pull Day',
      );
      expect(state.plan.daysForWeekday(DateTime.thursday), isEmpty);
      expect(state.plan.daysForWeekday(DateTime.sunday), isEmpty);
    });

    test('day six offers a choice of push or legs', () async {
      final state = await seeded();
      final saturday = state.plan.daysForWeekday(DateTime.saturday);
      expect(saturday.map((d) => d.name), containsAll(['Push Day', 'Leg Day']));
    });

    test(
      'the swapped-out inverted row stays on record but out of sessions',
      () async {
        final state = await seeded();
        final pull = dayNamed(state, 'Pull Day');
        final inverted = pull.items.firstWhere(
          (i) => i.exerciseId == 'inverted_row',
        );

        expect(inverted.active, isFalse);
        final session = state.startFromDay(pull);
        expect(
          session.exercises.any((e) => e.exerciseId == 'inverted_row'),
          isFalse,
        );
      },
    );

    test('goals seed with G1 primary and its markers', () async {
      final state = await seeded();
      expect(
        state.goals.map((g) => g.code),
        containsAll(['G1', 'G2', 'G3', 'G4', 'G5', 'G6', 'G7']),
      );
      final g1 = state.primaryGoal!;
      expect(g1.code, 'G1');
      expect(g1.markers, hasLength(6));
      expect(g1.testExerciseId, 'unassisted_pullup');
      expect(g1.milestones, hasLength(4));
    });

    test('every cable stack has a pin step recorded', () async {
      final state = await seeded();
      for (final id in const [
        'lat_pulldown',
        'seated_cable_row',
        'face_pull',
        'rope_pushdown',
        'pallof_press',
        'cable_crunch',
      ]) {
        expect(state.exerciseById(id).incrementKg, 6, reason: id);
      }
    });

    test('rest defaults follow the effort class of each exercise', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      final assisted = pull.items.firstWhere(
        (i) => i.exerciseId == 'assisted_pullup',
      );
      final curl = pull.items.firstWhere((i) => i.exerciseId == 'hammer_curl');

      expect(assisted.restSeconds, 150);
      expect(curl.restSeconds, 60);
    });
  });

  group('plan editing', () {
    test('a routine can hold several weekdays', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      state.toggleWeekday(legs, DateTime.sunday);
      expect(legs.weekdays, contains(DateTime.sunday));

      state.toggleWeekday(legs, DateTime.sunday);
      expect(legs.weekdays, isNot(contains(DateTime.sunday)));
    });

    test('new plan items inherit the exercise rest bucket', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      final item = state.addPlanItem(legs, 'plank');

      expect(item.restSeconds, 40);
      expect(item.repMin, 30, reason: 'timed exercises target seconds');
    });

    test('deleting an exercise clears the plan but keeps history', () async {
      final state = await seeded();
      final pull = dayNamed(state, 'Pull Day');
      logSession(
        state,
        pull,
        exerciseId: 'hammer_curl',
        sets: [(7.5, 12)],
        rpe: 8,
      );

      state.deleteExercise('hammer_curl');

      expect(pull.items.any((i) => i.exerciseId == 'hammer_curl'), isFalse);
      expect(state.pointsFor('hammer_curl'), hasLength(1));
      expect(state.exerciseName('hammer_curl'), 'Unknown exercise');
    });
  });

  group('the movement library', () {
    test('every stand-in points at a movement that exists', () async {
      final state = await seeded();
      final ids = {for (final e in state.exercises) e.id};

      for (final e in state.exercises) {
        for (final id in e.alternativeIds) {
          expect(
            ids,
            contains(id),
            reason: '${e.name} names a stand-in that is not in the library',
          );
          expect(id, isNot(e.id), reason: '${e.name} stands in for itself');
        }
        expect(
          e.alternativeIds.toSet(),
          hasLength(e.alternativeIds.length),
          reason: '${e.name} lists the same stand-in twice',
        );
      }
    });

    test('no two movements share an id', () async {
      final state = await seeded();
      final ids = state.exercises.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every muscle has something that trains it directly', () async {
      final state = await seeded();
      final targeted = state.exercises.map((e) => e.muscle).toSet();

      expect(
        targeted,
        containsAll(MuscleGroup.values),
        reason:
            'a muscle with no movement can never be covered, however '
            'the plan is rearranged',
      );
    });

    test('every muscle can be trained without free weights', () async {
      final state = await seeded();
      const loaded = {
        Equipment.machineStack,
        Equipment.machinePlateLoaded,
        Equipment.cable,
      };
      final covered = state.exercises
          .where((e) => loaded.contains(e.equipment))
          .map((e) => e.muscle)
          .toSet();

      for (final muscle in MuscleGroup.values) {
        // Grip is the exception: hanging and carrying are the whole point,
        // and no stack in the building trains it.
        if (muscle == MuscleGroup.grip) continue;
        expect(
          covered,
          contains(muscle),
          reason:
              'nothing on a stack or cable trains ${muscle.label}, so a '
              'busy free-weight floor leaves it untrainable',
        );
      }
    });

    test('every movement can be swapped for something', () async {
      final state = await seeded();

      for (final e in state.exercises) {
        expect(
          state.substitutesFor(e.id),
          isNotEmpty,
          reason: 'no stand-in offered for ${e.name}',
        );
      }
    });

    test('what a set records matches how it is loaded', () async {
      final state = await seeded();

      for (final e in state.exercises) {
        if (e.equipment == Equipment.bodyweight) {
          expect(
            e.loadSemantics,
            LoadSemantics.bodyweightOnly,
            reason: '${e.name} carries no external load',
          );
        }
        if (e.equipment == Equipment.assisted) {
          expect(
            e.loadSemantics,
            LoadSemantics.assistanceInverted,
            reason: '${e.name} gets easier as the number goes up',
          );
        }
        if (e.tracking == TrackingMode.weightReps &&
            e.loadSemantics == LoadSemantics.normal) {
          expect(e.equipment, isNot(Equipment.bodyweight));
        }
      }
    });
  });

  group('growing the library between versions', () {
    /// An install from before a movement shipped: everything else intact.
    Future<AppState> installWithout(
      String id, {
      void Function(Map)? edit,
    }) async {
      final original = await seeded();
      final json = original.toJson();
      (json['exercises'] as List).removeWhere((e) => (e as Map)['id'] == id);
      if (edit != null) edit(json);

      final state = AppState(storage: MemoryStorage()..data = json);
      await state.load();
      return state;
    }

    test(
      'a movement added by a new version arrives without a reinstall',
      () async {
        final state = await installWithout('hip_thrust');

        expect(state.exercises.any((e) => e.id == 'hip_thrust'), isTrue);
        expect(state.exerciseById('hip_thrust').muscle, MuscleGroup.glutes);
      },
    );

    test('it never overwrites what is already there', () async {
      final state = await installWithout(
        'hip_thrust',
        edit: (json) {
          for (final e in (json['exercises'] as List)) {
            if ((e as Map)['id'] == 'db_bench') {
              e['name'] = 'Bench, my numbers';
              e['incrementKg'] = 1.25;
            }
          }
        },
      );

      expect(state.exerciseById('db_bench').name, 'Bench, my numbers');
      expect(state.exerciseById('db_bench').incrementKg, 1.25);
    });

    test('one deleted on purpose stays deleted', () async {
      final state = await seeded();
      state.deleteExercise('wall_sit');

      final again = AppState(storage: MemoryStorage()..data = state.toJson());
      await again.load();

      expect(again.exercises.any((e) => e.id == 'wall_sit'), isFalse);
      expect(again.settings.removedExerciseIds, contains('wall_sit'));
    });

    test('a backup from an older version is topped up when restored', () async {
      final original = await seeded();
      final json = original.toJson();
      (json['exercises'] as List).removeWhere(
        (e) => (e as Map)['id'] == 'hack_squat',
      );

      final restored = AppState(storage: MemoryStorage())..importFrom(json);

      expect(restored.exercises.any((e) => e.id == 'hack_squat'), isTrue);
    });

    test('deleting a movement leaves nothing pointing at it', () async {
      final state = await seeded();
      expect(
        state.exerciseById('leg_press').alternativeIds,
        contains('bulgarian_split_squat'),
        reason: 'the link this test is about',
      );

      state.deleteExercise('bulgarian_split_squat');

      for (final e in state.exercises) {
        expect(e.alternativeIds, isNot(contains('bulgarian_split_squat')));
      }
      expect(
        state.substitutesFor('leg_press').map((o) => o.exercise.name),
        isNot(contains('Unknown exercise')),
      );
    });
  });

  group('exercise substitution', () {
    test('a pairing reads from both ends', () async {
      final state = await seeded();
      // The hack squat names the leg press; the leg press has never heard of
      // the hack squat.
      expect(
        state.exerciseById('hack_squat').alternativeIds,
        contains('leg_press'),
      );
      expect(
        state.exerciseById('leg_press').alternativeIds,
        isNot(contains('hack_squat')),
      );

      final option = state
          .substitutesFor('leg_press')
          .firstWhere((o) => o.exercise.id == 'hack_squat');

      expect(
        option.curated,
        isTrue,
        reason: 'a hand-made pair, just written down at the other end',
      );
    });

    test('its own picks still lead the ones that picked it', () async {
      final state = await seeded();
      final ids = state
          .substitutesFor('leg_press')
          .map((o) => o.exercise.id)
          .toList();

      for (final own in state.exerciseById('leg_press').alternativeIds) {
        expect(
          ids.indexOf(own),
          lessThan(ids.indexOf('hack_squat')),
          reason: 'the order in the list is a preference',
        );
      }
    });

    test('a movement nothing points at is still swappable', () async {
      final state = await seeded();
      final made = state.addExercise(
        'Some new machine',
        MuscleGroup.chest,
        Equipment.machineStack,
      );

      final options = state.substitutesFor(made.id);
      expect(options, isNotEmpty);
      expect(
        options.every((o) => o.curated),
        isFalse,
        reason: 'nothing was hand-picked — these come from the muscle',
      );
      expect(options.map((o) => o.exercise.id), isNot(contains(made.id)));
    });

    test('the reverse of a link is offered once, not twice', () async {
      final state = await seeded();
      // db_shrug and barbell_shrug name each other.
      final ids = state
          .substitutesFor('barbell_shrug')
          .map((o) => o.exercise.id);

      expect(ids.where((id) => id == 'db_shrug'), hasLength(1));
    });

    test('hand-picked stand-ins come before inferred ones', () async {
      final state = await seeded();
      final options = state.substitutesFor('leg_press');

      expect(options.take(3).map((o) => o.exercise.id), [
        'goblet_squat',
        'walking_lunge',
        'bulgarian_split_squat',
      ]);
      expect(options.take(3).every((o) => o.curated), isTrue);
      expect(options.map((o) => o.exercise.id), contains('leg_extension'));
      expect(options.map((o) => o.exercise.id), isNot(contains('leg_press')));
    });

    test('different kit is offered before more of the same', () async {
      final state = await seeded();
      state.addExercise(
        'Copenhagen plank',
        MuscleGroup.adductors,
        Equipment.bodyweight,
      );
      state.addExercise(
        'Adductor machine B',
        MuscleGroup.adductors,
        Equipment.machineStack,
      );

      final options = state.substitutesFor('hip_adductor');
      expect(options.first.exercise.name, 'Copenhagen plank');
      expect(options.last.exercise.name, 'Adductor machine B');
    });

    test('exercises already on today\'s card sink to the bottom', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      final session = state.startFromDay(legs);

      final options = state.substitutesFor(
        'leg_press',
        inSession: session.exercises.map((e) => e.exerciseId).toSet(),
      );
      final ids = options.map((o) => o.exercise.id).toList();

      // Still offered — you might legitimately double up — but never first.
      expect(ids, contains('bulgarian_split_squat'));
      expect(ids.first, 'goblet_squat');
      expect(options.first.alreadyInSession, isFalse);
      expect(options.last.alreadyInSession, isTrue);
      expect(
        options.indexWhere((o) => o.exercise.id == 'goblet_squat'),
        lessThan(
          options.indexWhere((o) => o.exercise.id == 'bulgarian_split_squat'),
        ),
      );
    });

    test('an untouched slot is swapped in place, keeping its shape', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      final session = state.startFromDay(legs);
      final press = session.exercises.firstWhere(
        (e) => e.exerciseId == 'leg_press',
      );
      final position = session.exercises.indexOf(press);

      final swapped = state.substituteExercise(session, press, 'goblet_squat');

      expect(session.exercises.indexOf(swapped), position);
      expect(
        session.exercises.any((e) => e.exerciseId == 'leg_press'),
        isFalse,
      );
      expect(swapped.substitutedForId, 'leg_press');
      expect(swapped.sets, hasLength(4));
      expect(swapped.repMin, 12);
      expect(swapped.repMax, 15);
      expect(swapped.restSeconds, 150, reason: 'the slot keeps its rest');
      expect(
        swapped.notes,
        isEmpty,
        reason: "the original's progression note does not apply",
      );
    });

    test('the load never carries across machines', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      final session = state.startFromDay(legs);
      final press = session.exercises.firstWhere(
        (e) => e.exerciseId == 'leg_press',
      );
      expect(press.sets.first.weight, 50, reason: 'planned leg press load');

      final swapped = state.substituteExercise(session, press, 'goblet_squat');
      expect(swapped.sets.every((s) => s.weight == 0), isTrue);
      expect(state.adviceFor('goblet_squat', 15).kind, AdviceKind.establish);
    });

    test('a stand-in prefills from its own history', () async {
      final state = await seeded();

      final warmUp = state.startEmptySession();
      final goblet = state.addExerciseToSession(warmUp, 'goblet_squat');
      for (final set in goblet.sets) {
        state.updateSet(set, weight: 24, reps: 10, done: true);
      }
      state.finishSession(warmUp);

      final legs = dayNamed(state, 'Leg Day');
      final session = state.startFromDay(legs);
      final press = session.exercises.firstWhere(
        (e) => e.exerciseId == 'leg_press',
      );
      final swapped = state.substituteExercise(session, press, 'goblet_squat');

      expect(swapped.sets.first.weight, 24);
      expect(swapped.sets.first.reps, 11, reason: 'one more than last time');
    });

    test('completed sets stay on the original when the machine goes', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      final session = state.startFromDay(legs);
      final press = session.exercises.firstWhere(
        (e) => e.exerciseId == 'leg_press',
      );
      final position = session.exercises.indexOf(press);

      state.completeSet(press, press.sets[0]);
      state.completeSet(press, press.sets[1]);

      final swapped = state.substituteExercise(session, press, 'goblet_squat');

      expect(press.sets, hasLength(2), reason: 'only what was actually done');
      expect(press.sets.every((s) => s.done), isTrue);
      expect(swapped.sets, hasLength(2), reason: 'the sets that were left');
      expect(session.exercises.indexOf(swapped), position + 1);
    });

    test('history keeps the two exercises apart', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      final session = state.startFromDay(legs);
      final press = session.exercises.firstWhere(
        (e) => e.exerciseId == 'leg_press',
      );

      state.completeSet(press, press.sets[0]);
      final swapped = state.substituteExercise(session, press, 'goblet_squat');
      for (final set in swapped.sets) {
        state.updateSet(set, weight: 24, reps: 12, done: true);
      }
      state.finishSession(session);

      expect(state.pointsFor('leg_press'), hasLength(1));
      expect(state.pointsFor('goblet_squat'), hasLength(1));
      expect(state.pointsFor('goblet_squat').single.topWeight, 24);
      expect(
        state.finishedSessions.single.exercises
            .firstWhere((e) => e.exerciseId == 'goblet_squat')
            .substitutedForId,
        'leg_press',
      );
    });

    test('swapping twice still points at what the plan asked for', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      final session = state.startFromDay(legs);
      final press = session.exercises.firstWhere(
        (e) => e.exerciseId == 'leg_press',
      );

      final first = state.substituteExercise(session, press, 'goblet_squat');
      final second = state.substituteExercise(session, first, 'walking_lunge');

      expect(second.exerciseId, 'walking_lunge');
      expect(second.substitutedForId, 'leg_press');
    });

    test('stand-in lists reject duplicates and self-reference', () async {
      final state = await seeded();
      final press = state.exerciseById('leg_press');
      final before = press.alternativeIds.length;

      state.addAlternative(press, 'goblet_squat'); // already there
      state.addAlternative(press, 'leg_press'); // itself
      expect(press.alternativeIds, hasLength(before));

      state.addAlternative(press, 'leg_extension');
      expect(press.alternativeIds, contains('leg_extension'));

      state.removeAlternative(press, 'leg_extension');
      expect(press.alternativeIds, isNot(contains('leg_extension')));
    });

    test('substitutions survive a backup round-trip', () async {
      final state = await seeded();
      final legs = dayNamed(state, 'Leg Day');
      final session = state.startFromDay(legs);
      final press = session.exercises.firstWhere(
        (e) => e.exerciseId == 'leg_press',
      );
      final swapped = state.substituteExercise(session, press, 'goblet_squat');
      state.updateSet(swapped.sets.first, weight: 24, reps: 12, done: true);
      state.finishSession(session);

      final restored = AppState(storage: MemoryStorage())
        ..importFrom(state.toJson());

      expect(
        restored.exerciseById('leg_press').alternativeIds,
        contains('goblet_squat'),
      );
      expect(
        restored.finishedSessions.single.exercises.single.substitutedForId,
        'leg_press',
      );
    });
  });
}
