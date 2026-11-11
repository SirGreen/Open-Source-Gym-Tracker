import '../models/models.dart';
import '../utils/plates.dart';

/// Load maths and the double-progression rules from the plan document.

/// What the set was actually worth, in kilograms of resistance.
///
/// * normal — the logged number, doubled for per-side loading. A machine's
///   base load is NOT added: on a plate-loaded machine you read the total off
///   the machine and log that, sled included, so adding the sled again would
///   count it twice. [ExerciseDef.baseLoadKg] exists to work out what to load,
///   not to inflate what was lifted.
/// * assistance-inverted — bodyweight minus the machine's help.
/// * bodyweight-only — bodyweight plus anything held or strapped on,
///   doubled first if that weight is logged per side.
double effectiveLoad(ExerciseDef def, SetEntry set, double bodyweightKg) {
  switch (def.loadSemantics) {
    case LoadSemantics.normal:
      return def.loadIsPerSide ? set.weight * 2 : set.weight;
    case LoadSemantics.assistanceInverted:
      final net = bodyweightKg - set.weight;
      return net < 0 ? 0 : net;
    case LoadSemantics.bodyweightOnly:
      final added = def.loadIsPerSide ? set.weight * 2 : set.weight;
      return bodyweightKg + added;
  }
}

/// Timed holds carry no rep volume, so they stay out of the volume totals.
double setVolume(ExerciseDef def, SetEntry set, double bodyweightKg) {
  if (!set.counts || def.tracking == TrackingMode.duration) return 0;
  return effectiveLoad(def, set, bodyweightKg) * set.reps;
}

/// Epley: 1RM = w × (1 + reps / 30).
double estimated1rm(ExerciseDef def, SetEntry set, double bodyweightKg) {
  if (set.reps <= 0 || def.tracking == TrackingMode.duration) return 0;
  final load = effectiveLoad(def, set, bodyweightKg);
  return load <= 0 ? 0 : load * (1 + set.reps / 30.0);
}

/// The number that means "better" for this exercise, used for charts, records
/// and goal markers.
///
/// Each tracking mode is scored by the thing that actually improves in it.
/// Epley only describes concentric work, so it would be meaningless on a
/// negative — you can lower a weight you cannot lift, which is the whole
/// reason negatives are programmed. Those progress by descent time, bodyweight
/// movements by reps, and holds by seconds.
double setScore(ExerciseDef def, SetEntry set, double bodyweightKg) =>
    switch (def.tracking) {
      TrackingMode.weightReps => estimated1rm(def, set, bodyweightKg),
      TrackingMode.bodyweightReps => set.reps.toDouble(),
      TrackingMode.duration => (set.durationSeconds ?? 0).toDouble(),
      TrackingMode.tempoReps => set.tempoSeconds ?? 0,
    };

/// A score written out with the unit it is actually in.
String formatScore(ExerciseDef def, double score) => switch (def.tracking) {
  TrackingMode.weightReps => '${_trim(score)} kg e1RM',
  TrackingMode.bodyweightReps => '${_trim(score)} reps',
  TrackingMode.duration => '${_trim(score)} s hold',
  TrackingMode.tempoReps => '${_trim(score)} s descent',
};

/// Axis label for the progress chart.
String scoreAxisLabel(ExerciseDef def) => switch (def.tracking) {
  TrackingMode.weightReps => 'Estimated 1RM (kg)',
  TrackingMode.bodyweightReps => 'Best set (reps)',
  TrackingMode.duration => 'Longest hold (s)',
  TrackingMode.tempoReps => 'Longest descent (s)',
};

/// What a set of this exercise counts toward the target range.
int achievedReps(ExerciseDef def, SetEntry set) =>
    def.tracking == TrackingMode.duration
    ? (set.durationSeconds ?? 0)
    : set.reps;

enum AdviceKind {
  /// All reps at the top of the range and the last set was RPE ≤ 8, for as
  /// many sessions in a row as the settings ask for.
  increase,

  /// The rule was met, but not yet often enough to act on.
  confirming,

  /// The rule was met, but this machine's step size is unknown so the app
  /// will not invent one.
  needsIncrement,

  /// Reps hit but no RPE logged — the rule cannot fire without it.
  needsRpe,

  /// Short of the top of the range: keep the weight, chase reps.
  addReps,

  /// At the top of the range but the last set was an RPE 9-10.
  hold,

  /// RPE 10 with form breaking down.
  reduce,

  /// Same load for three or more sessions without the difficulty rising.
  stale,

  /// No working weight recorded yet.
  establish,

  /// Never trained, or nothing comparable in the log.
  firstTime,
}

class ProgressionAdvice {
  const ProgressionAdvice(this.kind, this.message, {this.suggestedLoad});

  final AdviceKind kind;
  final String message;

  /// The load to move to, already adjusted for inverted assistance machines.
  final double? suggestedLoad;

  bool get isGo => kind == AdviceKind.increase;
  bool get earned =>
      kind == AdviceKind.increase ||
      kind == AdviceKind.confirming ||
      kind == AdviceKind.needsIncrement;
  bool get isWarning => kind == AdviceKind.reduce || kind == AdviceKind.stale;
}

String _trim(double v) => v == v.roundToDouble()
    ? v.round().toString()
    : v
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

String _kg(double v) => '${_trim(v)} kg';

/// How many of the most recent sessions in a row cleared the increase rule at
/// the same load. A change of load, a missed rep or a missing/hard RPE all end
/// the run — "consistently" means the same work done the same way.
int qualifyingStreak({
  required ExerciseDef def,
  required List<SessionExercise> history,
  required int repMax,
}) {
  var streak = 0;
  double? load;

  for (final performed in history) {
    final sets = performed.workingSets;
    if (sets.isEmpty) break;

    final thisLoad = sets.last.weight;
    if (load == null) {
      load = thisLoad;
    } else if ((thisLoad - load).abs() > 0.01) {
      break;
    }

    final rpe = performed.lastWorkingSet?.rpe;
    if (rpe == null || rpe > 8) break;
    if (!sets.every((s) => achievedReps(def, s) >= repMax)) break;

    streak++;
  }
  return streak;
}

/// Applies the plan's double-progression rules to the most recent performances
/// of one exercise. [history] is newest-first and holds only finished sessions.
/// [requiredSessions] is how many qualifying sessions in a row it takes before
/// the load is called earned.
ProgressionAdvice adviseProgression({
  required ExerciseDef def,
  required List<SessionExercise> history,
  required int repMax,
  double? plannedWeight,
  int requiredSessions = 1,
}) {
  final last = history.isEmpty ? null : history.first;
  final lastSets = last?.workingSets ?? const <SetEntry>[];

  if (last == null || lastSets.isEmpty) {
    if (def.tracking == TrackingMode.weightReps &&
        (plannedWeight == null || plannedWeight == 0)) {
      return const ProgressionAdvice(
        AdviceKind.establish,
        'No working weight yet — find one today and log the RPE.',
      );
    }
    return const ProgressionAdvice(
      AdviceKind.firstTime,
      'First time logging this — today sets the baseline.',
    );
  }

  final unit = def.tracking == TrackingMode.duration ? 's' : 'reps';
  final hitTop = lastSets.every((s) => achievedReps(def, s) >= repMax);
  final worst = lastSets
      .map((s) => achievedReps(def, s))
      .reduce((a, b) => a < b ? a : b);
  final lastRpe = last.lastWorkingSet?.rpe;
  final currentLoad = lastSets.last.weight;

  // Rule 3: some machines jump 20-33%, which is too much to take on schedule.
  final increment = def.incrementKg;
  final bigJump =
      increment != null && currentLoad > 0 && increment / currentLoad >= 0.15;

  if (!hitTop) {
    return ProgressionAdvice(
      AdviceKind.addReps,
      'Chase reps — last time the worst set was $worst $unit against a target '
      'of $repMax.',
    );
  }

  if (lastRpe == null) {
    return const ProgressionAdvice(
      AdviceKind.needsRpe,
      'All reps hit. Log an RPE on the last set — "completed all reps" alone '
      'does not say whether to add weight.',
    );
  }

  if (lastRpe >= 10) {
    return ProgressionAdvice(
      AdviceKind.reduce,
      'Last set was RPE 10 — hold ${_kg(currentLoad)}, or reduce if form broke '
      'down.',
    );
  }

  if (lastRpe >= 9) {
    return ProgressionAdvice(
      AdviceKind.hold,
      'RPE ${_fmtRpe(lastRpe)} at the top of the range — this is the sweet '
      'spot. Hold ${_kg(currentLoad)}.',
    );
  }

  // Reps at the top AND RPE <= 8: the one case that earns more weight.
  final streak = qualifyingStreak(def: def, history: history, repMax: repMax);
  if (streak < requiredSessions) {
    final left = requiredSessions - streak;
    return ProgressionAdvice(
      AdviceKind.confirming,
      'All $repMax $unit at RPE ${_fmtRpe(lastRpe)}. $left more session'
      '${left == 1 ? '' : 's'} like that and the load steps up on its own.',
    );
  }

  if (def.tracking != TrackingMode.weightReps) {
    return ProgressionAdvice(
      AdviceKind.increase,
      'All $repMax $unit at RPE ${_fmtRpe(lastRpe)} — raise the target, add a '
      'pause, or slow the tempo.',
    );
  }

  if (increment == null) {
    return ProgressionAdvice(
      AdviceKind.needsIncrement,
      'Earned an increase — go up one step on the machine. Record that step '
      "as the exercise's increment and the app can apply it for you next "
      'time.',
    );
  }

  final next = def.inverted ? currentLoad - increment : currentLoad + increment;
  final direction = def.inverted ? 'Drop assistance to' : 'Move up to';
  final caution = bigJump
      ? ' That is a ${(increment / currentLoad * 100).round()}% jump — expect '
            'reps to fall to the bottom of the range, or build extra reps first.'
      : '';

  return ProgressionAdvice(
    AdviceKind.increase,
    '$direction ${_kg(next < 0 ? 0 : next)}. All $repMax $unit at RPE '
    '${_fmtRpe(lastRpe)}.$caution',
    suggestedLoad: next < 0 ? 0 : next,
  );
}

// -------------------------------------------------------------- warm-up ramp

/// The ladder up to a working load: share of the top set, and the reps to do
/// there. Reps fall as the load climbs, so the ramp prepares the movement
/// without spending anything on it.
const warmupSteps = <({double fraction, int reps})>[
  (fraction: 0.4, reps: 8),
  (fraction: 0.6, reps: 5),
  (fraction: 0.8, reps: 3),
];

/// One warm-up set, in the same terms the exercise is logged in.
class WarmupSet {
  const WarmupSet({
    required this.weight,
    required this.reps,
    required this.fraction,
  });

  /// The number to select or load, exactly as a working set would record it.
  final double weight;
  final int reps;

  /// Share of the working load this set represents, for the label.
  final double fraction;
}

/// Whether a ramp is worth offering at all.
///
/// Isolation work warms up in its own first set — nobody needs a preparatory
/// set of lateral raises. A heavy or moderate compound does, and it is the
/// one place a warm-up changes how the working set goes.
bool warmupWorthwhile(ExerciseDef def) =>
    def.tracking == TrackingMode.weightReps &&
    def.loadSemantics != LoadSemantics.bodyweightOnly &&
    (def.effortClass == EffortClass.heavyCompound ||
        def.effortClass == EffortClass.moderateCompound);

/// The least resistance this movement can offer, in effective kilograms.
///
/// Not simply [effectiveLoad] of nothing: a barbell's logged number already
/// includes the bar, so its floor is the bar rather than zero, and an
/// assistance machine runs the other way — maximum help is its easiest
/// setting, not its hardest.
double _floorLoad(ExerciseDef def) => switch (def.loadSemantics) {
  LoadSemantics.assistanceInverted => 0,
  LoadSemantics.bodyweightOnly => 0,
  LoadSemantics.normal =>
    def.equipment == Equipment.barbell ? def.barKg : (def.baseLoadKg ?? 0),
};

/// The number to log for a wanted resistance — the inverse of [effectiveLoad].
///
/// Warm-ups are chosen in real resistance and logged in whatever the machine
/// happens to call it, so the two have to convert both ways.
double loggedWeightFor(ExerciseDef def, double effective, double bodyweightKg) {
  switch (def.loadSemantics) {
    case LoadSemantics.normal:
      final logged = def.loadIsPerSide ? effective / 2 : effective;
      return logged < 0 ? 0 : logged;
    case LoadSemantics.assistanceInverted:
      // Lighter means more help, so the logged number goes up as the ramp
      // goes down. Sending this the wrong way would warm you up on the
      // hardest sets of the day.
      final help = bodyweightKg - effective;
      return help < 0 ? 0 : help;
    case LoadSemantics.bodyweightOnly:
      // There is no lighter version of your own bodyweight.
      return 0;
  }
}

/// Rounds a load to something the equipment can actually be set to. Where the
/// step is unknown the number is left alone rather than invented — the same
/// rule the progression advice follows.
double snapToLoadable(ExerciseDef def, double logged, List<double> plates) {
  if (logged <= 0) return 0;

  if (def.equipment.usesPlates) {
    // Both are logged as the whole lift, so the bar or the sled comes off
    // before the rest is split into plates. Same convention as the plate
    // calculator, so a warm-up this suggests is one it can break down.
    final base = def.equipment == Equipment.barbell
        ? def.barKg
        : (def.baseLoadKg ?? 0);
    return calculatePlates(
      target: logged,
      barWeight: base,
      available: plates,
    ).achieved;
  }

  final step = def.incrementKg;
  if (step != null && step > 0) {
    final steps = (logged / step).round();
    return (steps < 1 ? 1 : steps) * step;
  }

  return double.parse(logged.toStringAsFixed(1));
}

/// The warm-up ladder leading to [workingLoad], lightest first.
///
/// Empty when a ramp would be meaningless: a movement that is not loaded by
/// weight, or a working load already so close to the empty bar that the first
/// working set is the warm-up.
List<WarmupSet> warmupRamp({
  required ExerciseDef def,
  required double workingLoad,
  required List<double> plates,
  double bodyweightKg = 0,
}) {
  if (def.tracking != TrackingMode.weightReps) return const [];
  if (def.loadSemantics == LoadSemantics.bodyweightOnly) return const [];

  final top = effectiveLoad(def, SetEntry(weight: workingLoad), bodyweightKg);
  final floor = _floorLoad(def);
  if (top <= floor) return const [];

  final out = <WarmupSet>[];
  for (final step in warmupSteps) {
    final wanted = top * step.fraction;
    // Below the bare bar there is nothing to load, and a set at the working
    // weight is not a warm-up.
    if (wanted <= floor || wanted >= top) continue;

    final logged = snapToLoadable(
      def,
      loggedWeightFor(def, wanted, bodyweightKg),
      plates,
    );

    // Snapping can collapse two steps onto the same plates; one set there is
    // enough. On an assistance machine the logged number falls as the ramp
    // climbs, so sameness is what matters, not direction.
    if (out.any((w) => (w.weight - logged).abs() < 0.01)) continue;
    if ((logged - workingLoad).abs() < 0.01) continue;

    out.add(
      WarmupSet(weight: logged, reps: step.reps, fraction: step.fraction),
    );
  }
  return out;
}

/// Rule: same load for 3+ sessions with the last set never harder than RPE 8.
/// Returns null when the exercise is not stale.
ProgressionAdvice? staleLoadFlag({
  required ExerciseDef def,
  required List<SessionExercise> history,
}) {
  if (def.tracking != TrackingMode.weightReps || history.length < 3)
    return null;

  final recent = history.take(3).toList();
  final loads = <double>[];
  for (final e in recent) {
    final sets = e.workingSets;
    if (sets.isEmpty) return null;
    loads.add(sets.last.weight);
    final rpe = e.lastWorkingSet?.rpe;
    if (rpe == null || rpe > 8) return null;
  }
  if (loads.any((l) => (l - loads.first).abs() > 0.01)) return null;

  return ProgressionAdvice(
    AdviceKind.stale,
    'Three sessions at ${_kg(loads.first)} and never harder than RPE 8 — time '
    'to push the load.',
  );
}

String _fmtRpe(double rpe) => rpe == rpe.roundToDouble()
    ? rpe.round().toString()
    : rpe.toStringAsFixed(1);

/// Cable stacks at this gym are labelled in pounds.
double kgToLb(double kg) => kg / 0.45359237;

// ------------------------------------------------------------ strength trend

/// A lift needs this many sessions before its direction means anything. Two
/// points make a line through noise as easily as through progress.
const trendMinimumSessions = 3;

/// Sessions that can pass without beating the best before the lift is stuck.
/// Two is a plateau you might train through; three is a pattern.
const trendStallSessions = 3;

/// How far under the best counts as going backwards rather than an off day.
/// Scores move a few percent on sleep and food alone.
const trendSlipMargin = 0.05;

/// A single off session does not mean a lift is regressing.
const trendSlipSessions = 2;

/// Which way a lift is going, read off its own score history.
enum TrendVerdict { climbing, holding, stalled, slipping, tooSoon }

extension TrendVerdictInfo on TrendVerdict {
  String get label => switch (this) {
    TrendVerdict.climbing => 'Climbing',
    TrendVerdict.holding => 'Holding',
    TrendVerdict.stalled => 'Stuck',
    TrendVerdict.slipping => 'Going backwards',
    TrendVerdict.tooSoon => 'Too early to say',
  };

  /// The short reason, for the row under the exercise name.
  String get meaning => switch (this) {
    TrendVerdict.climbing => 'last session was its best yet',
    TrendVerdict.holding => 'near its best, not past it',
    TrendVerdict.stalled => 'trained repeatedly without a new best',
    TrendVerdict.slipping => 'clearly under what it used to do',
    TrendVerdict.tooSoon => 'not enough sessions logged yet',
  };

  /// Whether this is a lift to go and look at.
  bool get needsAttention =>
      this == TrendVerdict.stalled || this == TrendVerdict.slipping;

  /// Worst first — the point of the list is the lifts that are not moving.
  int get rank => switch (this) {
    TrendVerdict.slipping => 0,
    TrendVerdict.stalled => 1,
    TrendVerdict.holding => 2,
    TrendVerdict.climbing => 3,
    TrendVerdict.tooSoon => 4,
  };
}

/// The last session that beat everything before it, by index.
///
/// Strictly beat: matching a mark set months ago is not progress, and on a
/// double-progression plan it is the definition of being stuck. The first
/// session always counts — it sets the mark the rest are measured against.
int lastImprovementIndex(List<double> scores) {
  var last = 0;
  var best = scores.isEmpty ? 0.0 : scores.first;
  for (var i = 1; i < scores.length; i++) {
    if (scores[i] > best) {
      best = scores[i];
      last = i;
    }
  }
  return last;
}

/// Reads a direction off one lift's scores, oldest first.
///
/// Measured against the best ever rather than a rolling average: what makes a
/// lift feel stuck is training it again and again without beating what you
/// already did, and an average hides exactly that.
TrendVerdict verdictForScores(List<double> scores) {
  if (scores.length < trendMinimumSessions) return TrendVerdict.tooSoon;

  final best = scores.reduce((a, b) => a > b ? a : b);
  if (best <= 0) return TrendVerdict.tooSoon;

  final sinceBest = scores.length - 1 - lastImprovementIndex(scores);
  if (sinceBest == 0) return TrendVerdict.climbing;

  final latest = scores.last;
  if (sinceBest >= trendSlipSessions && latest < best * (1 - trendSlipMargin)) {
    return TrendVerdict.slipping;
  }
  if (sinceBest >= trendStallSessions) return TrendVerdict.stalled;
  return TrendVerdict.holding;
}

// ---------------------------------------------------- weekly set volume

/// Weekly hard-set landmarks, per muscle group.
///
/// Hard sets per week — not tonnage, not session count — is the dose that
/// tracks with growth in the training literature, and the response to it is
/// graded rather than on/off. A handful of sets a week holds what you have,
/// around ten is where added size reliably shows, and past roughly twenty the
/// returns flatten while the fatigue does not.
///
/// One set of numbers is used for every muscle on purpose. Per-muscle
/// landmarks exist but disagree with each other by more than they agree, and
/// the gap between "two sets a week" and "twelve" swamps all of it.
class VolumeLandmarks {
  /// Below this a muscle is not even being held where it is.
  static const double maintenance = 4;

  /// Where added size reliably starts showing up.
  static const double minimumEffective = 10;

  /// Past here each extra set buys progressively less.
  static const double productiveCeiling = 20;

  /// The same sets split across two sessions beat one session at matched
  /// volume, so frequency is worth flagging separately from the total.
  static const double sessionsPerWeek = 2;

  /// A synergist is worked without being the point of the lift, so it banks
  /// part of a set rather than a whole one. Half is the usual convention:
  /// a bench press really does train triceps, just not as its main job.
  static const double synergistShare = 0.5;
}

/// Where a muscle's weekly volume sits against the landmarks.
enum VolumeVerdict { untrained, neglected, maintaining, productive, high }

extension VolumeVerdictInfo on VolumeVerdict {
  String get label => switch (this) {
    VolumeVerdict.untrained => 'Untrained',
    VolumeVerdict.neglected => 'Neglected',
    VolumeVerdict.maintaining => 'Holding only',
    VolumeVerdict.productive => 'On target',
    VolumeVerdict.high => 'Very high',
  };

  /// The short reason, for the row under the muscle name.
  String get meaning => switch (this) {
    VolumeVerdict.untrained => 'nothing logged in this window',
    VolumeVerdict.neglected => 'under the ~4 sets that maintain a muscle',
    VolumeVerdict.maintaining => 'enough to hold, short of the ~10 that build',
    VolumeVerdict.productive => 'inside the ~10-20 productive range',
    VolumeVerdict.high => 'past ~20 — returns flatten, fatigue does not',
  };

  bool get isShort =>
      this != VolumeVerdict.productive && this != VolumeVerdict.high;
}

VolumeVerdict verdictFor(double weeklySets) {
  if (weeklySets <= 0) return VolumeVerdict.untrained;
  if (weeklySets < VolumeLandmarks.maintenance) return VolumeVerdict.neglected;
  if (weeklySets < VolumeLandmarks.minimumEffective) {
    return VolumeVerdict.maintaining;
  }
  if (weeklySets <= VolumeLandmarks.productiveCeiling) {
    return VolumeVerdict.productive;
  }
  return VolumeVerdict.high;
}

// -------------------------------------------------------------------- energy

/// What lifting costs, in METs — multiples of the energy of sitting still.
/// The Compendium of Physical Activities puts resistance training with
/// multiple exercises at 3.5 for a light circuit and 6.0 for vigorous
/// bodybuilding work; 5.0 is the middle of that, and the honest answer for a
/// session run at the RPEs this plan asks for.
///
/// It is one figure rather than a curve on purpose. Effort could be read off
/// the logged RPE, but a scale that jumped 40% between RPE 7 and RPE 8 would
/// claim to know something no formula for this knows.
const trainingMet = 5.0;

/// How long a rep takes when nothing timed it.
const secondsPerRep = 3;

/// Kilocalories for [minutes] of training by someone of [bodyweightKg].
///
/// The standard MET arithmetic: one MET is 3.5 ml of oxygen per kilogram per
/// minute, and a litre of oxygen releases about 5 kcal — which is where the
/// 200 comes from. Heavier bodies move more mass and pay more for the same
/// session, which is the whole reason bodyweight is an input.
double kcalForTraining(double minutes, double bodyweightKg) {
  if (minutes <= 0 || bodyweightKg <= 0) return 0;
  return trainingMet * 3.5 * bodyweightKg / 200 * minutes;
}

/// How long one logged set stands for: the work itself, plus the rest it was
/// prescribed.
///
/// Modelled from the set rather than read off the clock, deliberately. A
/// session left open on a bench, or backfilled from a notebook days later, has
/// a wall-clock duration that says nothing about what was done — and the same
/// work has to cost the same whether or not you were quick about logging it.
/// Rest is counted rather than deducted because [trainingMet] is a
/// whole-session average that already assumes you rest between sets.
int setEffortSeconds(ExerciseDef def, SetEntry set, int restSeconds) {
  final work = switch (def.tracking) {
    TrackingMode.duration => set.durationSeconds ?? 0,
    // A slow descent is the work; a rep can never be quicker than a rep.
    TrackingMode.tempoReps => () {
      final tempo = set.tempoSeconds ?? 0;
      final per = tempo > secondsPerRep ? tempo : secondsPerRep.toDouble();
      return (set.reps * per).round();
    }(),
    _ => set.reps * secondsPerRep,
  };
  return work + (restSeconds < 0 ? 0 : restSeconds);
}
