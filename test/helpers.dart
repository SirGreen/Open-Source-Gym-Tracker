/// Fakes and fixtures shared by every test file.
library;

import 'dart:io';

import 'package:gym_tracker/data/app_state.dart';
import 'package:gym_tracker/data/storage.dart';
import 'package:gym_tracker/models/models.dart';

/// Keeps everything in memory so tests never touch path_provider.
class MemoryStorage extends Storage {
  Map<String, dynamic>? data;
  final List<Map<String, dynamic>> snapshots = [];
  String? text;
  int writes = 0;

  @override
  Future<Map<String, dynamic>?> load() async => data;

  @override
  Future<void> save(Map<String, dynamic> value) async {
    writes++;
    data = value;
  }

  @override
  Future<File> writeAutoBackup(
    Map<String, dynamic> value, {
    int keep = 10,
  }) async {
    snapshots.add(value);
    return File('memory-snapshot-${snapshots.length}');
  }

  @override
  Future<File> writeTextExport(String value, String name) async {
    text = value;
    return File(name);
  }
}

/// The real [Storage], pointed at a temp directory instead of path_provider's,
/// so file handling itself can be tested.
class TempStorage extends Storage {
  TempStorage(this.dir);

  final Directory dir;

  @override
  Future<File> file() async =>
      File('${dir.path}${Platform.pathSeparator}${Storage.fileName}');
}

Future<AppState> seeded() async {
  final state = AppState(storage: MemoryStorage());
  await state.load();
  return state;
}

/// A store whose "today" is fixed, so weekday-dependent behaviour is
/// deterministic instead of depending on when the suite runs.
Future<AppState> seededOn(DateTime when, {DateTime? trackingSince}) async {
  final state = AppState(storage: MemoryStorage(), clock: () => when);
  await state.load();
  // Default to an install that has been running a while, so the week is
  // judged normally; pass a date to exercise the fresh-install case.
  state.settings.trackingSince = trackingSince ?? DateTime(2026, 1, 1);
  return state;
}

/// Logs a minimal finished session dated to [date].
void logOn(AppState state, DateTime date, PlanDay day) {
  final session = state.startFromDay(day);
  final first = session.exercises.first;
  session.exercises.removeWhere((e) => e.id != first.id);
  first.sets.removeRange(1, first.sets.length);
  state.completeSet(first, first.sets.first);
  state.finishSession(session);
  session.start = date;
  session.end = date;
}

PlanDay dayNamed(AppState state, String name) =>
    state.plan.days.firstWhere((d) => d.name == name);

/// Logs one finished session containing a single exercise.
void logSession(
  AppState state,
  PlanDay day, {
  required String exerciseId,
  required List<(double, int)> sets,
  double? rpe,
  int? durationSeconds,
}) {
  final session = state.startFromDay(day);
  final se = session.exercises.firstWhere((e) => e.exerciseId == exerciseId);
  session.exercises.removeWhere((e) => e.id != se.id);

  se.sets.clear();
  for (final (weight, reps) in sets) {
    se.sets.add(
      SetEntry(
        weight: weight,
        reps: reps,
        durationSeconds: durationSeconds,
        done: true,
      ),
    );
  }
  if (rpe != null) state.setLastSetRpe(se, rpe);
  state.finishSession(session);
}
