import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../utils/formatting.dart';
import 'progression.dart';
import 'seed.dart';
import 'storage.dart';

// The class is split across parts rather than separate libraries: privacy
// in Dart is per library, so _touch and _storage stay reachable from every
// group while callers still see one AppState and import one file.
part 'app_state_library.dart';
part 'app_state_sessions.dart';
part 'app_state_stats.dart';
part 'app_state_goals.dart';
part 'app_state_io.dart';

/// Fallback descent time for a negative when there is nothing to copy —
/// matches the placeholder the empty field shows.
const defaultTempoSeconds = 2.0;

/// Double progression climbs a rep at a time; timed holds move in 5 s steps,
/// which is a difference you can actually feel on a hang or a plank.
const repStep = 1;
const durationStepSeconds = 5;

/// Next session's target for one set: a step past what was managed last time,
/// clamped to the top of the range. Once the ceiling is reached the target
/// holds there — the advice banner is what tells you to add weight, and reps
/// drop back to the floor when you do.
int nextTarget(int? previous, int rangeMin, int rangeMax, int step) {
  if (previous == null || previous <= 0) return rangeMin;
  if (previous >= rangeMax) return rangeMax;
  final next = previous + step;
  return next > rangeMax ? rangeMax : next;
}

/// One session's worth of an exercise, reduced to the numbers a chart needs.
class ExercisePoint {
  ExercisePoint({
    required this.date,
    required this.score,
    required this.volume,
    required this.topWeight,
    required this.topReps,
    required this.topDuration,
    required this.topTempo,
    required this.rpe,
    required this.sessionId,
  });

  final DateTime date;

  /// Estimated 1RM, or seconds for timed holds.
  final double score;
  final double volume;
  final double topWeight;
  final int topReps;
  final int topDuration;
  final double topTempo;
  final double? rpe;
  final String sessionId;
}

/// Tells "leave this field alone" apart from "clear it" when updating a
/// nullable field through a named argument.
const Object _keep = Object();

/// One muscle's weekly working-set count over the trailing window, split into
/// the sets that targeted it and the sets that merely worked it.
class MuscleVolume {
  MuscleVolume({
    required this.muscle,
    required this.directSets,
    required this.indirectSets,
    required this.sessionsPerWeek,
    required this.plannedDirectSets,
  });

  final MuscleGroup muscle;

  /// Sets per week where this muscle was the point of the lift.
  final double directSets;

  /// Sets per week where it was a synergist, already discounted.
  final double indirectSets;

  /// Distinct days per week that touched it, directly or otherwise.
  final double sessionsPerWeek;

  /// Direct sets a full week of the routine schedules, whatever you actually
  /// did. Separates a gap you left from a gap the plan has.
  final double plannedDirectSets;

  double get weeklySets => directSets + indirectSets;
  VolumeVerdict get verdict => verdictFor(weeklySets);

  /// Volume is fine but it all lands on one day.
  bool get lowFrequency =>
      !verdict.isShort && sessionsPerWeek < VolumeLandmarks.sessionsPerWeek;

  /// Nothing in the routine targets it directly — a gap by design, not by
  /// adherence.
  bool get missingFromPlan => plannedDirectSets <= 0;

  bool get needsAttention => verdict.isShort;
}

/// What one calendar day looks like against the plan.
enum DayStatus {
  /// No routine scheduled on this weekday.
  rest,

  /// A workout was finished.
  trained,

  /// Scheduled, in the past, nothing logged.
  missed,

  /// Missed and deliberately let go — no make-up offered.
  writtenOff,

  /// A scheduled day deliberately taken as rest. Not a miss, not owed.
  restTaken,

  /// Scheduled and still ahead.
  scheduled,

  /// Scheduled and it is today — still time.
  today,

  /// Before this install started tracking — not judged either way.
  untracked,
}

/// One line of "what this routine will open at".
class PlannedExercise {
  const PlannedExercise({
    required this.def,
    required this.opening,
    required this.advice,
  });

  final ExerciseDef def;

  /// Exactly the slot a real session would be given, sets and all. Not a
  /// description of one: built down the same path, so the preview cannot
  /// quietly drift from what pressing Start actually does.
  final SessionExercise opening;

  final ProgressionAdvice advice;

  /// The load the first set opens at, in this exercise's own logged terms.
  double get openingLoad =>
      opening.sets.isEmpty ? 0 : opening.sets.first.weight;

  /// The app is putting the bar up today off the back of previous sessions.
  bool get steppedUp => opening.autoProgressed;
}

/// A lift that beat its own record in the session just finished.
class SessionRecord {
  const SessionRecord({
    required this.def,
    required this.score,
    required this.previousBest,
  });

  final ExerciseDef def;
  final double score;

  /// Null the first time a lift is ever logged: there was nothing to beat.
  final double? previousBest;
}

/// What a finished workout is worth saying out loud.
class SessionSummary {
  const SessionSummary({
    required this.title,
    required this.sets,
    required this.volume,
    required this.duration,
    required this.records,
    required this.steppedUp,
    required this.droppedSets,
    required this.weekStreak,
    required this.calories,
  });

  final String title;
  final int sets;
  final double volume;
  final Duration duration;

  /// Estimated kilocalories. An estimate is all it can be, so the card that
  /// shows it says so.
  final double calories;

  /// Personal bests set today, one per lift.
  final List<SessionRecord> records;

  /// Lifts the app opened heavier today because the rule had been met — last
  /// week's work showing up as this week's weight.
  final List<ExerciseDef> steppedUp;

  /// Sets that were planned and not done. Counted before finishing, since
  /// finishing removes them.
  final int droppedSets;

  final int weekStreak;

  /// Everything planned was actually done.
  bool get cleanSweep => droppedSets == 0;

  /// How much of a fuss to make, 1 to 3. A record is the rare thing worth the
  /// full display; finishing at all is still worth something.
  int get fanfare {
    if (records.isNotEmpty) return 3;
    if (cleanSweep) return 2;
    return 1;
  }

  String get headline => switch (fanfare) {
    3 => records.length == 1 ? 'A new best' : '${records.length} new bests',
    2 => 'Every set done',
    _ => 'Session logged',
  };
}

/// One lift's direction of travel, ready to put on a row.
class ExerciseTrend {
  const ExerciseTrend({
    required this.def,
    required this.verdict,
    required this.sessions,
    required this.sessionsSinceBest,
    required this.best,
    required this.latest,
    required this.lastTrained,
    this.note,
  });

  final ExerciseDef def;
  final TrendVerdict verdict;

  /// Sessions inside the window this verdict was read from.
  final int sessions;

  /// Sessions since the last one that beat everything before it. Matching an
  /// old mark does not reset this: on a double-progression plan, repeating a
  /// number you already hit is the shape of a stall.
  final int sessionsSinceBest;

  final double best;
  final double latest;
  final DateTime? lastTrained;

  /// The stale-load message when it applies — the one that says what to do
  /// about it rather than only that something is wrong.
  final String? note;

  /// How far off the best the latest session was, as a share of it.
  double get shortfall => best <= 0 ? 0 : (best - latest) / best;
}

/// A scheduled training day still ahead of us.
class UpcomingDay {
  const UpcomingDay({required this.date, required this.days});

  final DateTime date;

  /// The routines scheduled on it — more than one on a choice day.
  final List<PlanDay> days;

  /// What a reminder should call it: the routine by name, or the choice.
  String get title =>
      days.length == 1 ? days.first.name : days.map((d) => d.name).join(' or ');
}

/// A scheduled day that did not happen and is still worth doing.
class MakeUp {
  MakeUp({
    required this.date,
    required this.options,
    required this.record,
    required this.servesPrimaryGoal,
  });

  final DateTime date;

  /// The routine(s) that were scheduled — more than one on a choice day.
  final List<PlanDay> options;

  /// The reason, if one was recorded.
  final MissedDay? record;
  final bool servesPrimaryGoal;
}

/// A candidate stand-in for an exercise whose machine or rack is occupied.
class SubstituteOption {
  SubstituteOption({
    required this.exercise,
    required this.curated,
    required this.alreadyInSession,
    required this.lastPerformed,
  });

  final ExerciseDef exercise;

  /// True when it was picked by hand rather than inferred from muscle group.
  final bool curated;

  /// Already scheduled today — still offered, but demoted, because picking it
  /// means training the same movement twice.
  final bool alreadyInSession;

  /// The most recent time this stand-in was trained, if ever.
  final SessionExercise? lastPerformed;
}

/// A goal marker resolved against the log.
class MarkerReading {
  MarkerReading({
    required this.marker,
    required this.current,
    required this.hasData,
  });

  final GoalMarker marker;
  final double current;
  final bool hasData;

  double get delta => current - marker.baseline;

  /// Positive when the number has moved the way the goal wants.
  double get progressDelta => marker.lowerIsBetter ? -delta : delta;
  bool get improved => progressDelta > 0.0001;
  bool get stalled => progressDelta.abs() <= 0.0001;
}

/// Single source of truth. Every mutation funnels through [_touch] so the UI
/// rebuilds and the JSON document is written (debounced).
class AppState extends ChangeNotifier {
  AppState({Storage? storage, DateTime Function()? clock})
    : _storage = storage ?? Storage(),
      _clock = clock ?? DateTime.now;

  final Storage _storage;

  /// Injectable so date-dependent behaviour — missed days, catch-ups, streaks
  /// — can be exercised without waiting for a particular weekday.
  final DateTime Function() _clock;

  DateTime get now => _clock();

  bool ready = false;
  AppSettings settings = AppSettings();
  TrainingPlan plan = TrainingPlan();
  List<ExerciseDef> exercises = [];
  List<Goal> goals = [];

  /// Scheduled days that did not happen, with the reason.
  List<MissedDay> missedDays = [];

  /// Dated weigh-ins, newest first.
  List<BodyweightEntry> bodyweights = [];

  /// Newest first. Includes the in-progress session, if any.
  List<WorkoutSession> sessions = [];

  Timer? _saveTimer;

  /// The stored document when it turned out to be from a newer version of the
  /// app, held back rather than applied.
  Map<String, dynamic>? _heldBack;

  /// The format version of that document, or null when there is no problem.
  ///
  /// An older build reading a newer file understands only the parts it already
  /// knew about, and the next save would write those back and quietly bin the
  /// rest. So nothing is applied and nothing is written until this is
  /// resolved: the file on disk stays exactly as the newer version left it.
  int? heldBackSchema;

  bool get blockedByNewerData => heldBackSchema != null;

  // ---------------------------------------------------------------- lifecycle

  Future<void> load() async {
    final data = await _storage.load();
    if (data == null) {
      _applySeed();
      unawaited(_saveNow());
    } else if (_schemaOf(data) > Storage.schemaVersion) {
      // Left unapplied on purpose. Nothing is seeded either: an empty app is
      // an honest thing to show behind the warning, where a seeded one looks
      // like a working install whose history has gone.
      _heldBack = data;
      heldBackSchema = _schemaOf(data);
    } else {
      _apply(data);
      // A version that ships new movements should not need a reinstall to
      // hand them over, so write them down straight away.
      if (_addShippedExercises()) unawaited(_saveNow());
    }
    ready = true;
    notifyListeners();
  }

  /// A document with no version is from before the field existed, which this
  /// build does understand.
  static int _schemaOf(Map<String, dynamic> data) =>
      (data['schema'] as num?)?.toInt() ?? Storage.schemaVersion;

  /// Gives up the parts this build cannot read and carries on with the rest.
  /// Everything the newer version added is gone as soon as anything saves,
  /// so this is only ever offered as a deliberate choice.
  void openAnyway() {
    final data = _heldBack;
    if (data == null) return;
    _heldBack = null;
    heldBackSchema = null;
    _apply(data);
    _addShippedExercises();
    _touch();
  }

  /// The database exactly as it sits on disk, copied out for safekeeping
  /// before anything touches it.
  Future<String> rescueRawFile() async {
    final stamp = now.toIso8601String().split('T').first;
    final f = await _storage.copyForExport('chalk-rescued-$stamp.json');
    return f.path;
  }

  void _applySeed() {
    exercises = seedExercises();
    plan = seedPlan();
    goals = seedGoals();
    sessions = [];
    missedDays = [];
    bodyweights = [];
    settings = AppSettings(trackingSince: dateOnly(now));
  }

  void _apply(Map<String, dynamic> data) {
    settings = data['settings'] is Map
        ? AppSettings.fromJson(
            Map<String, dynamic>.from(data['settings'] as Map),
          )
        : AppSettings();
    exercises = ((data['exercises'] as List?) ?? [])
        .map((e) => ExerciseDef.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (exercises.isEmpty) exercises = seedExercises();
    plan = data['plan'] is Map
        ? TrainingPlan.fromJson(Map<String, dynamic>.from(data['plan'] as Map))
        : seedPlan();
    goals = ((data['goals'] as List?) ?? [])
        .map((e) => Goal.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    sessions = ((data['sessions'] as List?) ?? [])
        .map(
          (e) => WorkoutSession.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    missedDays = ((data['missedDays'] as List?) ?? [])
        .map((e) => MissedDay.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    bodyweights = ((data['bodyweights'] as List?) ?? [])
        .map(
          (e) => BodyweightEntry.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    _sortBodyweights();
    _sortSessions();
    _backfillSynergists();
    _backfillAddedLoad();
    // Older backups predate the field; the first logged session is the best
    // stand-in for when tracking began.
    settings.trackingSince ??= sessions.isEmpty
        ? dateOnly(now)
        : dateOnly(sessions.last.start);
  }

  /// Synergist data arrived after this install was seeded, so fill it in for
  /// the movements that shipped with the app. Anything added by hand keeps
  /// whatever it has, which for a new exercise is nothing.
  void _backfillSynergists() {
    Map<String, ExerciseDef>? shipped;
    for (final e in exercises) {
      if (e.secondaryMuscles.isNotEmpty) continue;
      shipped ??= {for (final d in seedExercises()) d.id: d};
      final from = shipped[e.id];
      if (from != null) e.secondaryMuscles = [...from.secondaryMuscles];
    }
  }

  /// A bodyweight movement that ships taking added weight — dumbbells on a
  /// split squat — may still be reps-only here, from before it did. That copy
  /// has nowhere to log what is in your hands, so it gets the weight column.
  /// Only that exact state is touched; the old sets were bodyweight-only, so
  /// they read back as 0 kg on top and score the same as before.
  void _backfillAddedLoad() {
    Map<String, ExerciseDef>? shipped;
    for (final e in exercises) {
      if (e.tracking != TrackingMode.bodyweightReps) continue;
      shipped ??= {for (final d in seedExercises()) d.id: d};
      final from = shipped[e.id];
      if (from == null ||
          from.tracking != TrackingMode.weightReps ||
          from.loadSemantics != LoadSemantics.bodyweightOnly) {
        continue;
      }
      e.tracking = TrackingMode.weightReps;
      e.loadSemantics = LoadSemantics.bodyweightOnly;
      if (e.equipment == Equipment.bodyweight) e.equipment = from.equipment;
      e.incrementKg ??= from.incrementKg;
    }
  }

  /// Adds movements this version of the app ships but this install has
  /// never seen. Purely additive: an exercise already in the library keeps
  /// every edit made to it, and one deleted on purpose stays deleted.
  ///
  /// Returns true when the library actually grew.
  bool _addShippedExercises() {
    final have = {for (final e in exercises) e.id};
    final removed = settings.removedExerciseIds.toSet();
    var added = false;
    for (final def in seedExercises()) {
      if (have.contains(def.id) || removed.contains(def.id)) continue;
      exercises.add(def);
      added = true;
    }
    return added;
  }

  Map<String, dynamic> toJson() => {
    'schema': Storage.schemaVersion,
    'exportedAt': now.toIso8601String(),
    'settings': settings.toJson(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'plan': plan.toJson(),
    'goals': goals.map((e) => e.toJson()).toList(),
    'missedDays': missedDays.map((e) => e.toJson()).toList(),
    'bodyweights': bodyweights.map((e) => e.toJson()).toList(),
    'sessions': sessions.map((e) => e.toJson()).toList(),
  };

  void _sortSessions() => sessions.sort((a, b) => b.start.compareTo(a.start));

  void _sortBodyweights() =>
      bodyweights.sort((a, b) => b.date.compareTo(a.date));

  /// Rebuild now, write shortly. [eager] separates the edits worth persisting
  /// promptly — a set ticked off, a plan changed — from the ones that arrive a
  /// keystroke at a time while you type a weight. The whole document is
  /// re-serialised on every write, so typing "82.5" should not cost four of
  /// them. A hard kill can lose at most the last few seconds of typing;
  /// backgrounding flushes immediately.
  void _touch({bool eager = true}) {
    notifyListeners();
    if (blockedByNewerData) return;
    if (!eager && (_saveTimer?.isActive ?? false)) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(
      eager ? const Duration(milliseconds: 600) : const Duration(seconds: 5),
      _saveNow,
    );
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    // The last line of defence. Backgrounding the app calls flush() straight
    // through, so guarding only _touch would still let a lifecycle event
    // overwrite a document this build cannot fully read.
    if (blockedByNewerData) return;
    try {
      await _storage.save(toJson());
    } catch (e) {
      debugPrint('Save failed: $e');
    }
  }

  /// Called when the app leaves the foreground — never lose a logged set.
  Future<void> flush() => _saveNow();

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
