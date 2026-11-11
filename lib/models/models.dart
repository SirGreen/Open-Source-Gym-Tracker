import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Fresh random id for anything the user creates at runtime.
String newId() => _uuid.v4();

T _enumFrom<T extends Enum>(List<T> values, String? name, T fallback) =>
    values.firstWhere((e) => e.name == name, orElse: () => fallback);

// ---------------------------------------------------------------- enumerations

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  quads,
  hamstrings,
  glutes,
  abductors,
  adductors,
  calves,
  core,
  grip,
}

extension MuscleGroupInfo on MuscleGroup {
  String get label => switch (this) {
    MuscleGroup.chest => 'Chest',
    MuscleGroup.back => 'Back',
    MuscleGroup.shoulders => 'Shoulders',
    MuscleGroup.biceps => 'Biceps',
    MuscleGroup.triceps => 'Triceps',
    MuscleGroup.quads => 'Quads',
    MuscleGroup.hamstrings => 'Hamstrings',
    MuscleGroup.glutes => 'Glutes',
    MuscleGroup.abductors => 'Abductors',
    MuscleGroup.adductors => 'Adductors',
    MuscleGroup.calves => 'Calves',
    MuscleGroup.core => 'Core',
    MuscleGroup.grip => 'Grip',
  };
}

enum Equipment {
  barbell,
  dumbbell,
  cable,
  machineStack,
  machinePlateLoaded,
  bodyweight,
  assisted,
}

extension EquipmentInfo on Equipment {
  String get label => switch (this) {
    Equipment.barbell => 'Barbell',
    Equipment.dumbbell => 'Dumbbell',
    Equipment.cable => 'Cable',
    Equipment.machineStack => 'Machine (stack)',
    Equipment.machinePlateLoaded => 'Machine (plate-loaded)',
    Equipment.bodyweight => 'Bodyweight',
    Equipment.assisted => 'Assisted',
  };

  /// Anything you physically load with plates gets the plate calculator.
  bool get usesPlates =>
      this == Equipment.barbell || this == Equipment.machinePlateLoaded;
}

/// Which direction "harder" runs. Assistance machines are inverted: a lower
/// number means the machine is helping less, so the set is harder.
enum LoadSemantics { normal, assistanceInverted, bodyweightOnly }

/// What a set of this exercise actually records.
enum TrackingMode {
  /// Weight on the bar/stack plus reps.
  weightReps,

  /// Reps only — bodyweight movements.
  bodyweightReps,

  /// Seconds held — dead hangs, planks.
  duration,

  /// Reps plus the descent duration of each rep — pull-up negatives.
  tempoReps,
}

extension TrackingModeInfo on TrackingMode {
  bool get hasLoad => this == TrackingMode.weightReps;
  bool get hasReps => this != TrackingMode.duration;
  bool get hasDuration => this == TrackingMode.duration;
  bool get hasTempo => this == TrackingMode.tempoReps;

  String get label => switch (this) {
    TrackingMode.weightReps => 'Weight × reps',
    TrackingMode.bodyweightReps => 'Reps only',
    TrackingMode.duration => 'Time held',
    TrackingMode.tempoReps => 'Reps × tempo',
  };
}

/// Rest-between-sets bucket (see the plan's rest table).
enum EffortClass {
  heavyCompound,
  moderateCompound,
  isolation,
  machineIsolation,
  core,
}

extension EffortClassInfo on EffortClass {
  String get label => switch (this) {
    EffortClass.heavyCompound => 'Heavy compound',
    EffortClass.moderateCompound => 'Moderate compound',
    EffortClass.isolation => 'Isolation',
    EffortClass.machineIsolation => 'Machine isolation',
    EffortClass.core => 'Core',
  };

  int get restSeconds => switch (this) {
    EffortClass.heavyCompound => 150,
    EffortClass.moderateCompound => 90,
    EffortClass.isolation => 60,
    EffortClass.machineIsolation => 60,
    EffortClass.core => 40,
  };
}

/// Stacks at this gym are labelled in pounds, so kg values look odd
/// (18.3 kg = 40 lb). Kept per exercise so the UI can show both.
enum StackUnit { kg, lb }

/// Which palette the app paints in. Its own enum rather than Flutter's
/// ThemeMode so the model layer stays free of Flutter imports.
enum AppTheme { system, light, dark }

extension AppThemeInfo on AppTheme {
  String get label => switch (this) {
    AppTheme.system => 'Device',
    AppTheme.light => 'Light',
    AppTheme.dark => 'Dark',
  };
}

enum GoalType { strengthMilestone, physique, endurance, skill, habit, general }

extension GoalTypeInfo on GoalType {
  String get label => switch (this) {
    GoalType.strengthMilestone => 'Strength milestone',
    GoalType.physique => 'Physique',
    GoalType.endurance => 'Endurance',
    GoalType.skill => 'Skill',
    GoalType.habit => 'Habit',
    GoalType.general => 'General',
  };
}

enum GoalStatus { active, queued, achieved, paused, dropped }

extension GoalStatusInfo on GoalStatus {
  String get label => switch (this) {
    GoalStatus.active => 'In progress',
    GoalStatus.queued => 'Queued',
    GoalStatus.achieved => 'Achieved',
    GoalStatus.paused => 'Paused',
    GoalStatus.dropped => 'Dropped',
  };
}

/// What a goal marker reads off the training log.
enum MarkerMetric { topLoad, topReps, topDuration, topTempo, bodyweight }

extension MarkerMetricInfo on MarkerMetric {
  String get label => switch (this) {
    MarkerMetric.topLoad => 'Heaviest load',
    MarkerMetric.topReps => 'Most reps',
    MarkerMetric.topDuration => 'Longest hold',
    MarkerMetric.topTempo => 'Slowest descent',
    MarkerMetric.bodyweight => 'Bodyweight',
  };

  /// Suffix the goal screens print straight after the number.
  String get unit => switch (this) {
    MarkerMetric.topLoad || MarkerMetric.bodyweight => 'kg',
    MarkerMetric.topReps => '',
    MarkerMetric.topDuration || MarkerMetric.topTempo => 's',
  };

  /// The metric a movement can actually supply, given what its sets record.
  static MarkerMetric forTracking(TrackingMode tracking) => switch (tracking) {
    TrackingMode.weightReps => MarkerMetric.topLoad,
    TrackingMode.bodyweightReps => MarkerMetric.topReps,
    TrackingMode.duration => MarkerMetric.topDuration,
    TrackingMode.tempoReps => MarkerMetric.topTempo,
  };
}

// -------------------------------------------------------------------- exercise

class ExerciseDef {
  ExerciseDef({
    String? id,
    required this.name,
    this.muscle = MuscleGroup.core,
    this.equipment = Equipment.machineStack,
    List<MuscleGroup>? secondaryMuscles,
    this.loadSemantics = LoadSemantics.normal,
    this.tracking = TrackingMode.weightReps,
    this.effortClass = EffortClass.isolation,
    this.baseLoadKg,
    this.incrementKg,
    this.stackUnit = StackUnit.kg,
    this.loadIsPerSide = false,
    this.repsPerSide = false,
    this.barWeight = 0,
    this.notes = '',
    List<String>? alternativeIds,
  }) : id = id ?? newId(),
       secondaryMuscles = [...?secondaryMuscles],
       alternativeIds = alternativeIds ?? [];

  final String id;
  String name;
  MuscleGroup muscle;

  /// Synergists — the muscles that work but are not the point of the lift.
  /// Counted at a fraction of a set when judging weekly volume, because a
  /// bench press really does train triceps, just not as its main job.
  List<MuscleGroup> secondaryMuscles;

  Equipment equipment;
  LoadSemantics loadSemantics;
  TrackingMode tracking;
  EffortClass effortClass;

  /// The part of the logged number that is not plates — a leg-press sled or a
  /// frame. What gets logged is the whole resistance the machine shows, this
  /// included, so it is never added on top: it is taken off to work out how
  /// many plates to hang on. Compare [barWeight], which does the same job for
  /// a barbell.
  double? baseLoadKg;

  /// Smallest step this machine or rack allows, when it is known.
  double? incrementKg;

  StackUnit stackUnit;

  /// Dumbbells and plate-loaded machines: the logged number is per side.
  bool loadIsPerSide;

  /// Reps are counted per side (Pallof press, dead bug).
  bool repsPerSide;

  double barWeight;

  /// The bar a barbell lift is loaded on. 0 means it was never set — another
  /// kind of exercise switched to a barbell — and reads as an Olympic bar.
  double get barKg => barWeight > 0 ? barWeight : 20;

  String notes;

  /// Hand-picked stand-ins for when the machine or rack is taken, best first.
  List<String> alternativeIds;

  bool get inverted => loadSemantics == LoadSemantics.assistanceInverted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscle': muscle.name,
    'secondaryMuscles': secondaryMuscles.map((m) => m.name).toList(),
    'equipment': equipment.name,
    'loadSemantics': loadSemantics.name,
    'tracking': tracking.name,
    'effortClass': effortClass.name,
    'baseLoadKg': baseLoadKg,
    'incrementKg': incrementKg,
    'stackUnit': stackUnit.name,
    'loadIsPerSide': loadIsPerSide,
    'repsPerSide': repsPerSide,
    'barWeight': barWeight,
    'notes': notes,
    'alternativeIds': alternativeIds,
  };

  static ExerciseDef fromJson(Map<String, dynamic> j) => ExerciseDef(
    id: j['id'] as String?,
    name: j['name'] as String? ?? 'Exercise',
    muscle: _enumFrom(
      MuscleGroup.values,
      j['muscle'] as String?,
      MuscleGroup.core,
    ),
    secondaryMuscles: ((j['secondaryMuscles'] as List?) ?? [])
        .map(
          (e) => _enumFrom(MuscleGroup.values, e.toString(), MuscleGroup.core),
        )
        .toList(),
    equipment: _enumFrom(
      Equipment.values,
      j['equipment'] as String?,
      Equipment.machineStack,
    ),
    loadSemantics: _enumFrom(
      LoadSemantics.values,
      j['loadSemantics'] as String?,
      LoadSemantics.normal,
    ),
    tracking: _enumFrom(
      TrackingMode.values,
      j['tracking'] as String?,
      TrackingMode.weightReps,
    ),
    effortClass: _enumFrom(
      EffortClass.values,
      j['effortClass'] as String?,
      EffortClass.isolation,
    ),
    baseLoadKg: (j['baseLoadKg'] as num?)?.toDouble(),
    incrementKg: (j['incrementKg'] as num?)?.toDouble(),
    stackUnit: _enumFrom(
      StackUnit.values,
      j['stackUnit'] as String?,
      StackUnit.kg,
    ),
    loadIsPerSide: j['loadIsPerSide'] as bool? ?? false,
    repsPerSide: j['repsPerSide'] as bool? ?? false,
    barWeight: (j['barWeight'] as num?)?.toDouble() ?? 0,
    notes: j['notes'] as String? ?? '',
    alternativeIds: ((j['alternativeIds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}

// ------------------------------------------------------------------------ plan

/// One exercise slot inside a routine.
class PlanItem {
  PlanItem({
    String? id,
    required this.exerciseId,
    this.sets = 3,
    this.repMin = 8,
    this.repMax = 12,
    this.targetWeight,
    int? restSeconds,
    this.active = true,
    this.notes = '',
  }) : id = id ?? newId(),
       restSeconds = restSeconds ?? 90;

  final String id;
  String exerciseId;
  int sets;

  /// For duration-tracked exercises these are seconds, not reps.
  int repMin;
  int repMax;

  double? targetWeight;
  int restSeconds;

  /// Swapped-out slots stay on the routine, greyed out, so the decision is
  /// not silently lost (e.g. inverted rows, replaced by chest-supported row).
  bool active;
  String notes;

  String get repRange => repMin == repMax ? '$repMin' : '$repMin-$repMax';

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'sets': sets,
    'repMin': repMin,
    'repMax': repMax,
    'targetWeight': targetWeight,
    'restSeconds': restSeconds,
    'active': active,
    'notes': notes,
  };

  static PlanItem fromJson(Map<String, dynamic> j) => PlanItem(
    id: j['id'] as String?,
    exerciseId: j['exerciseId'] as String? ?? '',
    sets: (j['sets'] as num?)?.toInt() ?? 3,
    repMin: (j['repMin'] as num?)?.toInt() ?? 8,
    repMax: (j['repMax'] as num?)?.toInt() ?? 12,
    targetWeight: (j['targetWeight'] as num?)?.toDouble(),
    restSeconds: (j['restSeconds'] as num?)?.toInt(),
    active: j['active'] as bool? ?? true,
    notes: j['notes'] as String? ?? '',
  );
}

/// A routine — "Pull Day". Can sit on more than one weekday, which is how
/// pull gets two slots a week.
class PlanDay {
  PlanDay({
    String? id,
    required this.name,
    Set<int>? weekdays,
    this.focus = '',
    this.warmup = '',
    this.notes = '',
    List<String>? goalIds,
    List<PlanItem>? items,
  }) : id = id ?? newId(),
       weekdays = weekdays ?? <int>{},
       // Copied, not adopted: the seed passes const literals, and this list
       // is edited whenever a goal changes which routines serve it.
       goalIds = [...?goalIds],
       items = items ?? [];

  final String id;
  String name;

  /// 1 = Monday .. 7 = Sunday. Empty means "start it whenever".
  Set<int> weekdays;
  String focus;
  String warmup;
  String notes;

  /// Which goals this routine serves.
  List<String> goalIds;
  List<PlanItem> items;

  List<PlanItem> get activeItems => items.where((i) => i.active).toList();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'weekdays': weekdays.toList()..sort(),
    'focus': focus,
    'warmup': warmup,
    'notes': notes,
    'goalIds': goalIds,
    'items': items.map((e) => e.toJson()).toList(),
  };

  static PlanDay fromJson(Map<String, dynamic> j) {
    // Older backups stored a single nullable weekday.
    final raw = j['weekdays'];
    final days = <int>{};
    if (raw is List) {
      for (final v in raw) {
        if (v is num) days.add(v.toInt());
      }
    } else if (j['weekday'] is num) {
      days.add((j['weekday'] as num).toInt());
    }
    return PlanDay(
      id: j['id'] as String?,
      name: j['name'] as String? ?? 'Day',
      weekdays: days,
      focus: j['focus'] as String? ?? '',
      warmup: j['warmup'] as String? ?? '',
      notes: j['notes'] as String? ?? '',
      goalIds: ((j['goalIds'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      items: ((j['items'] as List?) ?? [])
          .map((e) => PlanItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class TrainingPlan {
  TrainingPlan({this.name = 'My Plan', List<PlanDay>? days})
    : days = days ?? [];

  String name;
  List<PlanDay> days;

  /// Every routine scheduled on a weekday. More than one means a choice day.
  List<PlanDay> daysForWeekday(int weekday) =>
      days.where((d) => d.weekdays.contains(weekday)).toList();

  PlanDay? byId(String? id) {
    if (id == null) return null;
    for (final d in days) {
      if (d.id == id) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'days': days.map((e) => e.toJson()).toList(),
  };

  static TrainingPlan fromJson(Map<String, dynamic> j) => TrainingPlan(
    name: j['name'] as String? ?? 'My Plan',
    days: ((j['days'] as List?) ?? [])
        .map((e) => PlanDay.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

// -------------------------------------------------------------------- logging

class SetEntry {
  SetEntry({
    String? id,
    this.weight = 0,
    this.reps = 0,
    this.durationSeconds,
    this.tempoSeconds,
    this.rpe,
    this.done = false,
    this.warmup = false,
    this.notes = '',
  }) : id = id ?? newId();

  final String id;

  /// The number actually selected or loaded, exactly as the plan says to
  /// record it (added plates, stack setting, assistance level).
  double weight;
  int reps;

  /// Holds: dead hangs, planks.
  int? durationSeconds;

  /// Negatives: seconds per descent.
  double? tempoSeconds;

  /// 6-10 difficulty rating. The single most useful field in the log.
  double? rpe;

  bool done;
  bool warmup;
  String notes;

  bool get counts => done && !warmup;

  SetEntry copyAsPending() => SetEntry(
    weight: weight,
    reps: reps,
    durationSeconds: durationSeconds,
    tempoSeconds: tempoSeconds,
    warmup: warmup,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'weight': weight,
    'reps': reps,
    'durationSeconds': durationSeconds,
    'tempoSeconds': tempoSeconds,
    'rpe': rpe,
    'done': done,
    'warmup': warmup,
    'notes': notes,
  };

  static SetEntry fromJson(Map<String, dynamic> j) => SetEntry(
    id: j['id'] as String?,
    weight: (j['weight'] as num?)?.toDouble() ?? 0,
    reps: (j['reps'] as num?)?.toInt() ?? 0,
    durationSeconds: (j['durationSeconds'] as num?)?.toInt(),
    tempoSeconds: (j['tempoSeconds'] as num?)?.toDouble(),
    rpe: (j['rpe'] as num?)?.toDouble(),
    done: j['done'] as bool? ?? false,
    warmup: j['warmup'] as bool? ?? false,
    notes: j['notes'] as String? ?? '',
  );
}

class SessionExercise {
  SessionExercise({
    String? id,
    required this.exerciseId,
    this.repMin = 8,
    this.repMax = 12,
    this.restSeconds = 90,
    this.targetWeight,
    this.notes = '',
    this.autoProgressed = false,
    this.previousLoad,
    this.substitutedForId,
    List<SetEntry>? sets,
  }) : id = id ?? newId(),
       sets = sets ?? [];

  final String id;
  String exerciseId;
  int repMin;
  int repMax;
  int restSeconds;
  double? targetWeight;
  String notes;

  /// True when the app opened this exercise at a heavier load than last time
  /// because the progression rule was met.
  bool autoProgressed;

  /// What the load was before that step, so the UI can show the jump.
  double? previousLoad;

  /// Set when this slot stands in for another exercise, so history records
  /// what was actually trained and why it differs from the plan.
  String? substitutedForId;
  List<SetEntry> sets;

  String get repRange => repMin == repMax ? '$repMin' : '$repMin-$repMax';

  int get doneCount => sets.where((s) => s.done).length;
  bool get complete => sets.isNotEmpty && sets.every((s) => s.done);
  List<SetEntry> get workingSets => sets.where((s) => s.counts).toList();

  /// The last completed working set — the one whose RPE drives progression.
  SetEntry? get lastWorkingSet {
    SetEntry? found;
    for (final s in sets) {
      if (s.counts) found = s;
    }
    return found;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'repMin': repMin,
    'repMax': repMax,
    'restSeconds': restSeconds,
    'targetWeight': targetWeight,
    'notes': notes,
    'autoProgressed': autoProgressed,
    'previousLoad': previousLoad,
    'substitutedForId': substitutedForId,
    'sets': sets.map((e) => e.toJson()).toList(),
  };

  static SessionExercise fromJson(Map<String, dynamic> j) => SessionExercise(
    id: j['id'] as String?,
    exerciseId: j['exerciseId'] as String? ?? '',
    repMin: (j['repMin'] as num?)?.toInt() ?? 8,
    repMax: (j['repMax'] as num?)?.toInt() ?? 12,
    restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 90,
    targetWeight: (j['targetWeight'] as num?)?.toDouble(),
    notes: j['notes'] as String? ?? '',
    autoProgressed: j['autoProgressed'] as bool? ?? false,
    previousLoad: (j['previousLoad'] as num?)?.toDouble(),
    substitutedForId: j['substitutedForId'] as String?,
    sets: ((j['sets'] as List?) ?? [])
        .map((e) => SetEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

class WorkoutSession {
  WorkoutSession({
    String? id,
    this.planDayId,
    required this.title,
    required this.start,
    this.end,
    this.bodyweightKg,
    this.notes = '',
    List<SessionExercise>? exercises,
  }) : id = id ?? newId(),
       exercises = exercises ?? [];

  final String id;
  String? planDayId;
  String title;
  DateTime start;
  DateTime? end;
  double? bodyweightKg;
  String notes;
  List<SessionExercise> exercises;

  bool get isActive => end == null;
  Duration durationAt(DateTime now) => (end ?? now).difference(start);
  int get doneSets => exercises.fold(0, (a, e) => a + e.doneCount);
  int get totalSets => exercises.fold(0, (a, e) => a + e.sets.length);

  Map<String, dynamic> toJson() => {
    'id': id,
    'planDayId': planDayId,
    'title': title,
    'start': start.toIso8601String(),
    'end': end?.toIso8601String(),
    'bodyweightKg': bodyweightKg,
    'notes': notes,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  static WorkoutSession fromJson(Map<String, dynamic> j) => WorkoutSession(
    id: j['id'] as String?,
    planDayId: j['planDayId'] as String?,
    title: j['title'] as String? ?? 'Workout',
    start: DateTime.tryParse(j['start'] as String? ?? '') ?? DateTime.now(),
    end: j['end'] == null ? null : DateTime.tryParse(j['end'] as String),
    bodyweightKg: (j['bodyweightKg'] as num?)?.toDouble(),
    notes: j['notes'] as String? ?? '',
    exercises: ((j['exercises'] as List?) ?? [])
        .map(
          (e) => SessionExercise.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );
}

// ------------------------------------------------------------------------ goals

/// One number worth watching on the way to a goal.
class GoalMarker {
  GoalMarker({
    required this.label,
    required this.metric,
    this.exerciseId,
    required this.baseline,
    this.lowerIsBetter = false,
    this.unit = '',
  });

  final String label;
  final MarkerMetric metric;
  final String? exerciseId;
  final double baseline;

  /// Assistance weight and bodyweight both improve by going down.
  final bool lowerIsBetter;
  final String unit;

  Map<String, dynamic> toJson() => {
    'label': label,
    'metric': metric.name,
    'exerciseId': exerciseId,
    'baseline': baseline,
    'lowerIsBetter': lowerIsBetter,
    'unit': unit,
  };

  static GoalMarker fromJson(Map<String, dynamic> j) => GoalMarker(
    label: j['label'] as String? ?? '',
    metric: _enumFrom(
      MarkerMetric.values,
      j['metric'] as String?,
      MarkerMetric.topLoad,
    ),
    exerciseId: j['exerciseId'] as String?,
    baseline: (j['baseline'] as num?)?.toDouble() ?? 0,
    lowerIsBetter: j['lowerIsBetter'] as bool? ?? false,
    unit: j['unit'] as String? ?? '',
  );
}

class Milestone {
  Milestone({required this.label, this.eta = '', this.done = false});

  String label;
  String eta;
  bool done;

  Map<String, dynamic> toJson() => {'label': label, 'eta': eta, 'done': done};

  static Milestone fromJson(Map<String, dynamic> j) => Milestone(
    label: j['label'] as String? ?? '',
    eta: j['eta'] as String? ?? '',
    done: j['done'] as bool? ?? false,
  );
}

class Goal {
  Goal({
    String? id,
    required this.code,
    required this.title,
    this.type = GoalType.physique,
    this.target = '',
    DateTime? startedAt,
    this.status = GoalStatus.active,
    this.primary = false,
    this.notes = '',
    this.testExerciseId,
    this.testIntervalDays = 14,
    List<GoalMarker>? markers,
    List<Milestone>? milestones,
  }) : id = id ?? newId(),
       startedAt = startedAt ?? DateTime.now(),
       markers = markers ?? [],
       milestones = milestones ?? [];

  final String id;

  /// Short handle from the plan document — G1, G2 …
  String code;
  String title;
  GoalType type;
  String target;
  DateTime startedAt;
  GoalStatus status;

  /// Exactly one goal is primary; routine changes are judged against it.
  bool primary;
  String notes;

  /// A goal like "first unassisted pull-up" is only really measured by
  /// attempting it. This is the movement that counts as an attempt.
  String? testExerciseId;

  /// How often to attempt it. Testing every session just adds fatigue.
  int testIntervalDays;
  List<GoalMarker> markers;
  List<Milestone> milestones;

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'title': title,
    'type': type.name,
    'target': target,
    'startedAt': startedAt.toIso8601String(),
    'status': status.name,
    'primary': primary,
    'notes': notes,
    'testExerciseId': testExerciseId,
    'testIntervalDays': testIntervalDays,
    'markers': markers.map((e) => e.toJson()).toList(),
    'milestones': milestones.map((e) => e.toJson()).toList(),
  };

  static Goal fromJson(Map<String, dynamic> j) => Goal(
    id: j['id'] as String?,
    code: j['code'] as String? ?? '',
    title: j['title'] as String? ?? 'Goal',
    type: _enumFrom(GoalType.values, j['type'] as String?, GoalType.physique),
    target: j['target'] as String? ?? '',
    startedAt:
        DateTime.tryParse(j['startedAt'] as String? ?? '') ?? DateTime.now(),
    status: _enumFrom(
      GoalStatus.values,
      j['status'] as String?,
      GoalStatus.active,
    ),
    primary: j['primary'] as bool? ?? false,
    notes: j['notes'] as String? ?? '',
    testExerciseId: j['testExerciseId'] as String?,
    testIntervalDays: (j['testIntervalDays'] as num?)?.toInt() ?? 14,
    markers: ((j['markers'] as List?) ?? [])
        .map((e) => GoalMarker.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    milestones: ((j['milestones'] as List?) ?? [])
        .map((e) => Milestone.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}

// ------------------------------------------------------------- missed days

/// Why a scheduled day did not happen. Drives whether the app offers to make
/// it up or lets it go.
enum MissReason { illness, injury, travel, work, gymClosed, tired, other, rest }

extension MissReasonInfo on MissReason {
  String get label => switch (this) {
    MissReason.illness => 'Ill',
    MissReason.injury => 'Injury',
    MissReason.travel => 'Away',
    MissReason.work => 'Work / life',
    MissReason.gymClosed => 'Gym closed',
    MissReason.tired => 'Too beat up',
    MissReason.other => 'Something else',
    MissReason.rest => 'Rest day',
  };

  /// Rest is a decision, not something that got in the way, so it never
  /// appears among the reasons a session fell over.
  bool get isRest => this == MissReason.rest;

  /// Reasons where forcing a make-up is the wrong call — the plan already
  /// says to rest when the body asks for it.
  bool get suggestsRest =>
      this == MissReason.injury ||
      this == MissReason.illness ||
      this == MissReason.tired;

  /// The things that can be picked as an excuse on the missed-day sheet.
  static List<MissReason> get excuses =>
      MissReason.values.where((r) => !r.isRest).toList();
}

/// A scheduled training day that did not happen.
class MissedDay {
  MissedDay({
    String? id,
    required DateTime date,
    this.planDayId,
    this.reason = MissReason.other,
    this.note = '',
    this.writtenOff = false,
  }) : id = id ?? newId(),
       date = DateTime(date.year, date.month, date.day);

  final String id;
  final DateTime date;

  /// Which routine was scheduled, when there was exactly one.
  String? planDayId;
  MissReason reason;
  String note;

  /// True once you decide not to make it up — it stops being offered.
  bool writtenOff;

  /// A rest day taken on purpose. Nothing is owed and nothing was lost, so it
  /// reads differently from a session that simply did not happen.
  bool get isRest => reason.isRest;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'planDayId': planDayId,
    'reason': reason.name,
    'note': note,
    'writtenOff': writtenOff,
  };

  static MissedDay fromJson(Map<String, dynamic> j) => MissedDay(
    id: j['id'] as String?,
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    planDayId: j['planDayId'] as String?,
    reason: _enumFrom(
      MissReason.values,
      j['reason'] as String?,
      MissReason.other,
    ),
    note: j['note'] as String? ?? '',
    writtenOff: j['writtenOff'] as bool? ?? false,
  );
}

// --------------------------------------------------------------- bodyweight

/// One dated weigh-in. Day-to-day weight swings more than months of real
/// change, so these are read as a rolling average rather than one at a time.
class BodyweightEntry {
  BodyweightEntry({
    String? id,
    required DateTime date,
    required this.kg,
    this.note = '',
  }) : id = id ?? newId(),
       date = DateTime(date.year, date.month, date.day);

  final String id;
  final DateTime date;
  double kg;
  String note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'kg': kg,
    'note': note,
  };

  static BodyweightEntry fromJson(Map<String, dynamic> j) => BodyweightEntry(
    id: j['id'] as String?,
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    kg: (j['kg'] as num?)?.toDouble() ?? 0,
    note: j['note'] as String? ?? '',
  );
}

// --------------------------------------------------------------------- settings

class AppSettings {
  AppSettings({
    this.bodyweightKg = 80,
    this.vibrate = true,
    this.autoRest = true,
    List<double>? plates,
    this.showLbHint = true,
    this.autoProgress = true,
    this.autoProgressSessions = 1,
    this.trackingSince,
    this.lastExportedAt,
    this.theme = AppTheme.dark,
    this.remindTraining = false,
    this.remindHour = 17,
    this.remindMinute = 0,
    List<String>? removedExerciseIds,
  }) : plates = plates ?? [25, 20, 15, 10, 5, 2.5, 1.25],
       removedExerciseIds = removedExerciseIds ?? [];

  double bodyweightKg;
  bool vibrate;
  bool autoRest;
  List<double> plates;

  /// Cable stacks here are labelled in pounds; show the conversion at a glance.
  bool showLbHint;

  /// Apply the earned load increase to the next session instead of only
  /// suggesting it.
  bool autoProgress;

  /// How many sessions in a row at the same load must meet the rule before the
  /// weight steps up on its own.
  int autoProgressSessions;

  /// The day this install started tracking. Days before it are not judged —
  /// a fresh install has not missed anything.
  DateTime? trackingSince;

  /// When a backup last left the device. Automatic backups stay on the phone,
  /// so this is the one that matters if the phone does not survive.
  DateTime? lastExportedAt;

  /// Dark by default: this app is used in a gym, and every install before
  /// this setting existed was dark whether it wanted to be or not.
  AppTheme theme;

  /// Remind me on days the plan schedules and I have not trained yet.
  bool remindTraining;

  /// When to send it, on the phone's own clock.
  int remindHour;
  int remindMinute;

  /// Movements deleted from the library on purpose. New app versions top the
  /// library up with whatever they ship; this is the list that stops a
  /// deliberate deletion coming back with the next update.
  List<String> removedExerciseIds;

  Map<String, dynamic> toJson() => {
    'bodyweightKg': bodyweightKg,
    'vibrate': vibrate,
    'autoRest': autoRest,
    'plates': plates,
    'showLbHint': showLbHint,
    'autoProgress': autoProgress,
    'autoProgressSessions': autoProgressSessions,
    'trackingSince': trackingSince?.toIso8601String(),
    'lastExportedAt': lastExportedAt?.toIso8601String(),
    'theme': theme.name,
    'remindTraining': remindTraining,
    'remindHour': remindHour,
    'remindMinute': remindMinute,
    'removedExerciseIds': removedExerciseIds,
  };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
    bodyweightKg: (j['bodyweightKg'] as num?)?.toDouble() ?? 80,
    vibrate: j['vibrate'] as bool? ?? true,
    autoRest: j['autoRest'] as bool? ?? true,
    plates: ((j['plates'] as List?) ?? const [25, 20, 15, 10, 5, 2.5, 1.25])
        .map((e) => (e as num).toDouble())
        .toList(),
    showLbHint: j['showLbHint'] as bool? ?? true,
    autoProgress: j['autoProgress'] as bool? ?? true,
    autoProgressSessions: (j['autoProgressSessions'] as num?)?.toInt() ?? 1,
    trackingSince: DateTime.tryParse(j['trackingSince'] as String? ?? ''),
    lastExportedAt: DateTime.tryParse(j['lastExportedAt'] as String? ?? ''),
    theme: _enumFrom(AppTheme.values, j['theme'] as String?, AppTheme.dark),
    remindTraining: j['remindTraining'] as bool? ?? false,
    remindHour: (j['remindHour'] as num?)?.toInt() ?? 17,
    remindMinute: (j['remindMinute'] as num?)?.toInt() ?? 0,
    removedExerciseIds: ((j['removedExerciseIds'] as List?) ?? [])
        .map((e) => e.toString())
        .toList(),
  );
}
