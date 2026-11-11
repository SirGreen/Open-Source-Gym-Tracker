import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/data/storage.dart';
import 'package:gym_tracker/models/models.dart';

import 'helpers.dart';

void main() {
  group('save cadence', () {
    test('ticking a set is written promptly', () async {
      final storage = MemoryStorage();
      final state = AppState(storage: storage);
      await state.load();
      final baseline = storage.writes;

      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final first = session.exercises.first;
      state.completeSet(first, first.sets.first);
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(storage.writes, greaterThan(baseline));
    });

    test('typing a weight does not write on every keystroke', () async {
      final storage = MemoryStorage();
      final state = AppState(storage: storage);
      await state.load();

      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final baseline = storage.writes;

      final set = session.exercises.first.sets.first;
      for (final w in [8.0, 82.0, 82.5]) {
        state.updateSet(set, weight: w);
      }
      await Future<void>.delayed(const Duration(milliseconds: 900));

      expect(
        storage.writes,
        baseline,
        reason: 'still pending on the slower timer',
      );
      expect(set.weight, 82.5, reason: 'the value is live regardless');
    });
  });

  group('backup safety', () {
    final wednesday = DateTime(2026, 9, 2);

    test('a snapshot is written after every finished workout', () async {
      final storage = MemoryStorage();
      final state = AppState(storage: storage, clock: () => wednesday);
      await state.load();

      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      state.completeSet(
        session.exercises.first,
        session.exercises.first.sets.first,
      );
      state.finishSession(session);
      await Future<void>.delayed(Duration.zero);

      expect(storage.snapshots, hasLength(1));
      expect(storage.snapshots.single['sessions'], isNotEmpty);
    });

    test('a discarded workout leaves no snapshot', () async {
      final storage = MemoryStorage();
      final state = AppState(storage: storage, clock: () => wednesday);
      await state.load();

      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      state.finishSession(session); // nothing logged, so it is discarded
      await Future<void>.delayed(Duration.zero);

      expect(storage.snapshots, isEmpty);
    });

    test('an install that never exported is overdue', () async {
      final state = await seededOn(wednesday);
      expect(state.daysSinceExport, isNull);
      expect(state.exportOverdue, isTrue);

      state.settings.lastExportedAt = wednesday.subtract(
        const Duration(days: 3),
      );
      expect(state.daysSinceExport, 3);
      expect(state.exportOverdue, isFalse);

      state.settings.lastExportedAt = wednesday.subtract(
        const Duration(days: 20),
      );
      expect(state.exportOverdue, isTrue);
    });
  });

  group('backup', () {
    test('export json round-trips through import', () async {
      final state = await seeded();
      logSession(
        state,
        dayNamed(state, 'Pull Day'),
        exerciseId: 'lat_pulldown',
        sets: [(24, 12)],
        rpe: 8,
      );
      state.updateSettings(bodyweightKg: 79.5);

      final restored = AppState(storage: MemoryStorage())
        ..importFrom(state.toJson());

      expect(restored.settings.bodyweightKg, 79.5);
      expect(restored.plan.days, hasLength(state.plan.days.length));
      expect(restored.goals, hasLength(state.goals.length));
      expect(restored.primaryGoal!.code, 'G1');
      expect(dayNamed(restored, 'Pull Day').weekdays, {
        DateTime.monday,
        DateTime.friday,
      });
      expect(
        restored.finishedSessions.single.exercises.single.lastWorkingSet!.rpe,
        8,
      );
    });

    test('a single legacy weekday still imports', () async {
      final state = await seeded();
      final json = state.toJson();
      final firstDay = (json['plan'] as Map)['days'][0] as Map;
      firstDay.remove('weekdays');
      firstDay['weekday'] = DateTime.wednesday;

      final restored = AppState(storage: MemoryStorage())..importFrom(json);
      expect(restored.plan.days.first.weekdays, {DateTime.wednesday});
    });

    test('rejects a file that is not a backup', () async {
      final state = await seeded();
      expect(
        () => state.importFrom({'hello': 'world'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('the chosen theme comes back with the backup', () async {
      final state = await seeded();
      state.updateSettings(theme: AppTheme.system, remindTraining: true);

      final restored = AppState(storage: MemoryStorage())
        ..importFrom(state.toJson());
      expect(restored.settings.theme, AppTheme.system);
      expect(restored.settings.remindTraining, isTrue);
    });

    test('refuses a backup written by a newer version', () async {
      final state = await seeded();
      final json = state.toJson();
      json['schema'] = Storage.schemaVersion + 1;

      // Importing it would drop whatever that version added without saying so,
      // and the file is only intact until it is imported.
      expect(
        () => AppState(storage: MemoryStorage()).importFrom(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('a backup from before the schema field still imports', () async {
      final state = await seeded();
      final json = state.toJson()..remove('schema');

      final restored = AppState(storage: MemoryStorage())..importFrom(json);
      expect(restored.plan.days.length, state.plan.days.length);
    });
  });

  group('saving the database', () {
    test('a save lands on top of the previous one in a single step', () async {
      final dir = await Directory.systemTemp.createTemp('chalk-save');
      addTearDown(() => dir.delete(recursive: true));
      final storage = TempStorage(dir);

      await storage.save({'schema': Storage.schemaVersion, 'marker': 'first'});
      await storage.save({'schema': Storage.schemaVersion, 'marker': 'second'});

      // Overwriting must never go through "delete, then rename": that leaves a
      // moment with no database on disk, which is the crash this temp file is
      // meant to survive.
      expect((await storage.load())?['marker'], 'second');
      expect(File('${(await storage.file()).path}.tmp').existsSync(), isFalse);
    });
  });

  group('data from a newer version', () {
    /// A store already holding a real, populated document written in a format
    /// this build does not know.
    Future<MemoryStorage> fromFuture() async {
      final seed = await seeded();
      logSession(
        seed,
        dayNamed(seed, 'Pull Day'),
        exerciseId: 'lat_pulldown',
        sets: [(40, 10)],
        rpe: 8,
      );
      final doc = seed.toJson()..['schema'] = Storage.schemaVersion + 1;
      return MemoryStorage()..data = doc;
    }

    test('it is held back rather than opened', () async {
      final state = AppState(storage: await fromFuture());
      await state.load();

      expect(state.blockedByNewerData, isTrue);
      expect(state.heldBackSchema, Storage.schemaVersion + 1);
      // Not applied and not seeded: an empty app is honest, a seeded one looks
      // like an install whose history has gone.
      expect(state.plan.days, isEmpty);
      expect(state.sessions, isEmpty);
      expect(state.exercises, isEmpty);
    });

    test('nothing overwrites it while it is held back', () async {
      final storage = await fromFuture();
      final state = AppState(storage: storage);
      await state.load();

      // Every route to the disk: an edit, and the flush that backgrounding
      // the app fires straight past the debounce.
      state.updateSettings(vibrate: false);
      await state.flush();

      expect(storage.writes, 0);
      expect(storage.data!['schema'], Storage.schemaVersion + 1);
    });

    test('opening it anyway keeps what this build understands', () async {
      final storage = await fromFuture();
      final state = AppState(storage: storage);
      await state.load();

      state.openAnyway();

      expect(state.blockedByNewerData, isFalse);
      expect(state.plan.days, isNotEmpty);
      expect(state.finishedSessions, hasLength(1));
      // And writing is live again.
      await state.flush();
      expect(storage.writes, greaterThan(0));
    });

    test('a document this build wrote opens normally', () async {
      final seed = await seeded();
      final storage = MemoryStorage()..data = seed.toJson();
      final state = AppState(storage: storage);
      await state.load();

      expect(state.blockedByNewerData, isFalse);
      expect(state.plan.days, isNotEmpty);
    });

    test('a document from before the version field opens normally', () async {
      final seed = await seeded();
      final doc = seed.toJson()..remove('schema');
      final state = AppState(storage: MemoryStorage()..data = doc);
      await state.load();

      expect(state.blockedByNewerData, isFalse);
      expect(state.plan.days, isNotEmpty);
    });
  });

  group('csv export', () {
    test('a completed set lands under the right columns', () async {
      final state = await seeded();
      logSession(
        state,
        dayNamed(state, 'Pull Day'),
        exerciseId: 'lat_pulldown',
        sets: [(24, 12)],
        rpe: 8,
      );

      final lines = state.toCsv().split('\r\n');
      expect(lines.length, 2);

      final header = lines.first.split(',');
      final cells = lines[1].split(',');
      String cell(String name) => cells[header.indexOf(name)];

      expect(cell('exercise'), 'Lat pulldown');
      expect(cell('routine'), 'Pull Day');
      expect(cell('weight_kg'), '24');
      expect(cell('reps'), '12');
      expect(cell('rpe'), '8');
      expect(cell('warmup'), 'no');
      expect(cell('volume_kg'), '288');
    });

    test('a note with a comma is quoted rather than split', () async {
      final state = await seeded();
      final day = dayNamed(state, 'Pull Day');
      final session = state.startFromDay(day);
      final se = session.exercises.first;
      session.exercises.removeWhere((e) => e.id != se.id);
      se.sets.removeRange(1, se.sets.length);
      se.sets.first.notes = 'felt "off", left side';
      state.updateSet(se.sets.first, reps: 8, done: true);
      state.finishSession(session);

      final row = state.toCsv().split('\r\n')[1];
      expect(row, contains('"felt ""off"", left side"'));
    });

    test('warm-up sets are flagged, not dropped', () async {
      final state = await seeded();
      final session = state.startFromDay(dayNamed(state, 'Pull Day'));
      final se = session.exercises.first;
      session.exercises.removeWhere((e) => e.id != se.id);
      se.sets.removeRange(1, se.sets.length);
      state.updateSet(se.sets.first, reps: 10, done: true, warmup: true);
      state.finishSession(session);

      final lines = state.toCsv().split('\r\n');
      final header = lines.first.split(',');
      expect(lines.length, 2);
      expect(lines[1].split(',')[header.indexOf('warmup')], 'yes');
      // It happened, so it is in the log — it just earns no volume.
      expect(lines[1].split(',')[header.indexOf('volume_kg')], '0');
    });

    test('exporting a csv does not count as a backup', () async {
      final storage = MemoryStorage();
      final state = AppState(storage: storage);
      await state.load();
      logSession(
        state,
        dayNamed(state, 'Pull Day'),
        exerciseId: 'lat_pulldown',
        sets: [(24, 12)],
        rpe: 8,
      );

      await state.exportCsvToFile();

      // Nothing can be restored from a csv, so it must not silence the
      // warning that nothing has left the phone.
      expect(state.settings.lastExportedAt, isNull);
      expect(state.exportOverdue, isTrue);
      expect(storage.text, contains('Lat pulldown'));
    });
  });
}
