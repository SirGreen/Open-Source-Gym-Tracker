import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';

import 'helpers.dart';

void main() {
  group('weigh-in management', () {
    final wednesday = DateTime(2026, 9, 2);

    test('a weigh-in can be back-dated without touching today', () async {
      final state = await seededOn(wednesday);
      state.logBodyweight(80, date: wednesday);
      state.logBodyweight(
        82,
        date: wednesday.subtract(const Duration(days: 3)),
      );

      expect(state.bodyweights, hasLength(2));
      expect(state.bodyweights.first.date, wednesday, reason: 'newest first');
      expect(state.averageBodyweight(), closeTo(81, 0.001));
    });

    test('a bad reading can be removed', () async {
      final state = await seededOn(wednesday);
      state.logBodyweight(
        79,
        date: wednesday.subtract(const Duration(days: 1)),
      );
      final typo = state.logBodyweight(795, date: wednesday);
      expect(state.averageBodyweight(), closeTo(437, 0.001));

      state.deleteBodyweight(typo.id);

      expect(state.bodyweights, hasLength(1));
      expect(state.averageBodyweight(), 79);
      expect(state.currentBodyweight, 79);
    });

    test('deleting the last one falls back to the setting', () async {
      final state = await seededOn(wednesday);
      final only = state.logBodyweight(77, date: wednesday);
      state.deleteBodyweight(only.id);

      expect(state.bodyweights, isEmpty);
      expect(state.averageBodyweight(), isNull);
      expect(
        state.currentBodyweight,
        77,
        reason: 'the last known value, not a reset to the seed default',
      );
    });

    test('a note rides along with the entry', () async {
      final state = await seededOn(wednesday);
      state.logBodyweight(78.4, date: wednesday, note: 'after a big weekend');

      final restored = AppState(
        storage: MemoryStorage(),
        clock: () => wednesday,
      )..importFrom(state.toJson());
      expect(restored.bodyweights.single.note, 'after a big weekend');
    });
  });

  group('bodyweight', () {
    final wednesday = DateTime(2026, 9, 2);

    test('a weigh-in replaces the same day rather than stacking up', () async {
      final state = await seededOn(wednesday);
      state.logBodyweight(80);
      state.logBodyweight(79.4);

      expect(state.bodyweights, hasLength(1));
      expect(state.bodyweights.single.kg, 79.4);
    });

    test('the headline is a 7-day mean, not the last number', () async {
      final state = await seededOn(wednesday);
      state.logBodyweight(80, date: wednesday);
      state.logBodyweight(
        79,
        date: wednesday.subtract(const Duration(days: 1)),
      );
      state.logBodyweight(
        78,
        date: wednesday.subtract(const Duration(days: 2)),
      );

      expect(state.averageBodyweight(), closeTo(79, 0.001));
    });

    test('entries outside the window fall back to the latest', () async {
      final state = await seededOn(wednesday);
      state.logBodyweight(
        84,
        date: wednesday.subtract(const Duration(days: 40)),
      );

      expect(state.averageBodyweight(), 84);
      expect(state.averageBodyweight(days: 60), 84);
    });

    test('with no weigh-ins it falls back to the setting', () async {
      final state = await seededOn(wednesday);
      expect(state.averageBodyweight(), isNull);
      expect(state.currentBodyweight, 80);
    });

    test('the average drives net pull on the assist machine', () async {
      final state = await seededOn(wednesday);
      state.logBodyweight(76, date: wednesday);
      state.logBodyweight(
        78,
        date: wednesday.subtract(const Duration(days: 1)),
      );

      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      expect(state.bodyweightFor(session), closeTo(77, 0.001));

      final assisted = session.exercises.firstWhere(
        (e) => e.exerciseId == 'assisted_pullup',
      );
      state.updateSet(assisted.sets.first, weight: 55, reps: 10, done: true);

      // 77 kg of you minus 55 kg of help, ten times.
      expect(state.exerciseVolume(session, assisted), closeTo(220, 0.01));
    });

    test('the goal marker reads the average', () async {
      final state = await seededOn(wednesday);
      state.logBodyweight(78, date: wednesday);
      state.logBodyweight(
        80,
        date: wednesday.subtract(const Duration(days: 1)),
      );

      final marker = state.primaryGoal!.markers.firstWhere(
        (m) => m.label == 'Bodyweight',
      );
      final reading = state.readMarker(marker);

      expect(reading.current, closeTo(79, 0.001));
      expect(reading.hasData, isTrue);
      expect(reading.improved, isTrue, reason: 'baseline was 80');
    });

    test('weighing in during a workout is still a weigh-in', () async {
      final state = await seededOn(wednesday);
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      state.setSessionBodyweight(session, 77.5);

      expect(state.bodyweights.single.kg, 77.5);
      expect(session.bodyweightKg, 77.5);
    });

    test('weigh-ins survive a backup round-trip', () async {
      final state = await seededOn(wednesday);
      state.logBodyweight(79.2, date: wednesday, note: 'morning');

      final restored = AppState(
        storage: MemoryStorage(),
        clock: () => wednesday,
      )..importFrom(state.toJson());

      expect(restored.bodyweights.single.kg, 79.2);
      expect(restored.bodyweights.single.note, 'morning');
    });
  });
}
