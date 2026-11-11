import '../models/models.dart';

/// The movement library, the Pull/Push/Legs rotation and the goal list, all
/// taken from the training plan document.

// ------------------------------------------------------------------ exercises

List<ExerciseDef> seedExercises() => [
  // ---- Pull ----------------------------------------------------------
  ExerciseDef(
    id: 'pullup_negative',
    alternativeIds: ['assisted_pullup'],
    name: 'Pull-up negatives',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.biceps,
      MuscleGroup.grip,
      MuscleGroup.shoulders,
    ],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.tempoReps,
    effortClass: EffortClass.heavyCompound,
    notes: 'Log the descent duration. 2 s now, 5 s is the next milestone.',
  ),
  ExerciseDef(
    id: 'unassisted_pullup',
    name: 'Unassisted pull-up',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.biceps,
      MuscleGroup.grip,
      MuscleGroup.shoulders,
    ],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.heavyCompound,
    notes:
        'The goal itself. One honest attempt every couple of weeks — '
        'log 0 if it does not move, that is still a data point.',
  ),
  ExerciseDef(
    id: 'scap_pullup',
    name: 'Scapular pull-ups',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.grip, MuscleGroup.shoulders],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.moderateCompound,
  ),
  ExerciseDef(
    id: 'assisted_pullup',
    alternativeIds: ['lat_pulldown', 'scap_pullup'],
    name: 'Assisted pull-ups',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.biceps,
      MuscleGroup.grip,
      MuscleGroup.shoulders,
    ],
    equipment: Equipment.assisted,
    loadSemantics: LoadSemantics.assistanceInverted,
    effortClass: EffortClass.heavyCompound,
    incrementKg: 5,
    notes: 'Lower assistance = harder. Progress means this number drops.',
  ),
  ExerciseDef(
    id: 'lat_pulldown',
    alternativeIds: ['assisted_pullup'],
    name: 'Lat pulldown',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.biceps, MuscleGroup.grip],
    equipment: Equipment.cable,
    effortClass: EffortClass.moderateCompound,
    stackUnit: StackUnit.lb,
    incrementKg: 6,
    notes: 'Stack is lb-labelled; 24 kg ≈ 53 lb.',
  ),
  ExerciseDef(
    id: 'chest_supported_row',
    alternativeIds: ['seated_cable_row', 'inverted_row'],
    name: 'Chest-supported row',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.biceps, MuscleGroup.shoulders],
    equipment: Equipment.machinePlateLoaded,
    effortClass: EffortClass.moderateCompound,
    notes:
        'Base machine resistance unknown — track added plates only. '
        'Open item: confirm whether 20 kg is per side or total.',
  ),
  ExerciseDef(
    id: 'seated_cable_row',
    alternativeIds: ['chest_supported_row', 'inverted_row'],
    name: 'Seated cable row',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.biceps,
      MuscleGroup.shoulders,
      MuscleGroup.grip,
    ],
    equipment: Equipment.cable,
    effortClass: EffortClass.moderateCompound,
    stackUnit: StackUnit.lb,
    incrementKg: 6,
  ),
  ExerciseDef(
    id: 'hammer_curl',
    alternativeIds: ['incline_db_curl'],
    name: 'Hammer curl',
    muscle: MuscleGroup.biceps,
    secondaryMuscles: const [MuscleGroup.grip],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.isolation,
    loadIsPerSide: true,
  ),
  ExerciseDef(
    id: 'incline_db_curl',
    alternativeIds: ['hammer_curl'],
    name: 'Incline dumbbell curl',
    muscle: MuscleGroup.biceps,
    secondaryMuscles: const [MuscleGroup.grip],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.isolation,
    loadIsPerSide: true,
    notes: 'Hardest curl variation — slow progress is normal.',
  ),
  ExerciseDef(
    id: 'dead_hang',
    name: 'Dead hangs',
    muscle: MuscleGroup.grip,
    secondaryMuscles: const [MuscleGroup.back, MuscleGroup.shoulders],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.duration,
    effortClass: EffortClass.isolation,
    notes:
        'Benchmark: 30 s okay, 60 s solid. Skin pain adapts in 2–4 '
        'weeks — stop when the skin pinches, not when grip fails.',
  ),
  ExerciseDef(
    id: 'inverted_row',
    name: 'Inverted row',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.biceps,
      MuscleGroup.shoulders,
      MuscleGroup.core,
      MuscleGroup.grip,
    ],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.moderateCompound,
    notes: 'Dropped — setup annoying, form hard to get right.',
  ),

  // ---- Push ----------------------------------------------------------
  ExerciseDef(
    id: 'db_bench',
    alternativeIds: ['pushup', 'incline_bb_bench', 'pec_deck'],
    name: 'Dumbbell bench press',
    muscle: MuscleGroup.chest,
    secondaryMuscles: const [MuscleGroup.triceps, MuscleGroup.shoulders],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.moderateCompound,
    loadIsPerSide: true,
    incrementKg: 2.5,
  ),
  ExerciseDef(
    id: 'incline_bb_bench',
    alternativeIds: ['db_bench', 'pushup'],
    name: 'Incline barbell bench',
    muscle: MuscleGroup.chest,
    secondaryMuscles: const [MuscleGroup.triceps, MuscleGroup.shoulders],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 20,
    incrementKg: 5,
    notes: 'Currently the empty 20 kg bar. +2.5 kg per side = +5 kg total.',
  ),
  ExerciseDef(
    id: 'pec_deck',
    alternativeIds: ['pushup', 'db_bench'],
    name: 'Pec deck / cable fly',
    muscle: MuscleGroup.chest,
    secondaryMuscles: const [MuscleGroup.shoulders],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    notes: 'Open item: establish a working weight.',
  ),
  ExerciseDef(
    id: 'lateral_raise',
    name: 'Lateral raises',
    muscle: MuscleGroup.shoulders,
    secondaryMuscles: const [],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.isolation,
    loadIsPerSide: true,
    incrementKg: 2.5,
    notes: "Don't chase weight — swinging turns it into a shrug.",
  ),
  ExerciseDef(
    id: 'rear_delt_fly',
    alternativeIds: ['face_pull'],
    name: 'Rear delt fly',
    muscle: MuscleGroup.shoulders,
    secondaryMuscles: const [MuscleGroup.back],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.isolation,
    loadIsPerSide: true,
    notes:
        'Open item: establish a weight. Also helps shoulder position '
        'for pull-ups.',
  ),
  ExerciseDef(
    id: 'face_pull',
    incrementKg: 6,
    alternativeIds: ['rear_delt_fly'],
    name: 'Face pulls',
    muscle: MuscleGroup.shoulders,
    secondaryMuscles: const [MuscleGroup.back],
    equipment: Equipment.cable,
    effortClass: EffortClass.isolation,
    stackUnit: StackUnit.lb,
  ),
  ExerciseDef(
    id: 'close_grip_bench',
    alternativeIds: ['rope_pushdown', 'pushup'],
    name: 'Close-grip bench',
    muscle: MuscleGroup.triceps,
    secondaryMuscles: const [MuscleGroup.chest, MuscleGroup.shoulders],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 20,
    incrementKg: 5,
    notes:
        'Harder on elbows and wrists than flat bench — groove first, '
        'load second.',
  ),
  ExerciseDef(
    id: 'rope_pushdown',
    incrementKg: 6,
    alternativeIds: ['oh_db_extension', 'close_grip_bench'],
    name: 'Rope pushdown',
    muscle: MuscleGroup.triceps,
    secondaryMuscles: const [],
    equipment: Equipment.cable,
    effortClass: EffortClass.isolation,
    stackUnit: StackUnit.lb,
    notes: '18.3 kg = 40 lb.',
  ),
  ExerciseDef(
    id: 'oh_db_extension',
    name: 'Overhead dumbbell extension',
    muscle: MuscleGroup.triceps,
    secondaryMuscles: const [],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.isolation,
    notes: 'Single dumbbell, both hands. From the old standalone arm day.',
  ),
  ExerciseDef(
    id: 'hanging_knee_raise',
    alternativeIds: ['dead_bug', 'cable_crunch'],
    name: 'Hanging knee raises',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [MuscleGroup.grip, MuscleGroup.back],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.core,
    notes: 'Doubles as grip work.',
  ),
  ExerciseDef(
    id: 'pallof_press',
    incrementKg: 6,
    alternativeIds: ['dead_bug', 'plank'],
    name: 'Pallof press',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [MuscleGroup.shoulders],
    equipment: Equipment.cable,
    effortClass: EffortClass.core,
    stackUnit: StackUnit.lb,
    repsPerSide: true,
    notes: 'Anti-rotation. Cable at chest height.',
  ),
  ExerciseDef(
    id: 'plank',
    alternativeIds: ['dead_bug'],
    name: 'Plank',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [MuscleGroup.shoulders],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.duration,
    effortClass: EffortClass.core,
  ),

  // ---- Legs ----------------------------------------------------------
  ExerciseDef(
    id: 'leg_press',
    alternativeIds: ['goblet_squat', 'walking_lunge', 'bulgarian_split_squat'],
    name: 'Leg press',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [MuscleGroup.glutes, MuscleGroup.adductors],
    equipment: Equipment.machinePlateLoaded,
    effortClass: EffortClass.heavyCompound,
    baseLoadKg: 40,
    incrementKg: 10,
    notes: 'Sled weighs 40 kg — log the plates you add on top.',
  ),
  ExerciseDef(
    id: 'bulgarian_split_squat',
    alternativeIds: ['walking_lunge', 'goblet_squat'],
    name: 'Bulgarian split squat',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [MuscleGroup.glutes, MuscleGroup.hamstrings],
    equipment: Equipment.dumbbell,
    // Bodyweight is most of the load, so it stays a bodyweight movement;
    // the logged kilos are whatever is in your hands on top of it, and 0
    // is a perfectly good answer while it is still bodyweight only.
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.weightReps,
    effortClass: EffortClass.moderateCompound,
    incrementKg: 2.5,
    notes:
        'Do it early in the session for real reps. Bodyweight until '
        '10–12 clean, then add dumbbells — log the total you are '
        'holding.',
  ),
  ExerciseDef(
    id: 'hip_abductor',
    alternativeIds: ['side_lying_abduction'],
    name: 'Hip abductor (outer)',
    muscle: MuscleGroup.abductors,
    secondaryMuscles: const [MuscleGroup.glutes],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    notes: 'Priority movement for balancing outer vs inner thigh.',
  ),
  ExerciseDef(
    id: 'hip_adductor',
    name: 'Hip adductor (inner)',
    muscle: MuscleGroup.adductors,
    secondaryMuscles: const [],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    notes: 'Keep slightly behind the abductor.',
  ),
  ExerciseDef(
    id: 'leg_extension',
    alternativeIds: ['goblet_squat', 'walking_lunge'],
    name: 'Leg extension',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    incrementKg: 4.5,
    notes: 'Machine jumps 22.5 → 27 kg — a 20% step. Build reps first.',
  ),
  ExerciseDef(
    id: 'lying_leg_curl',
    alternativeIds: ['db_rdl'],
    name: 'Lying leg curl',
    muscle: MuscleGroup.hamstrings,
    secondaryMuscles: const [MuscleGroup.calves],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    incrementKg: 5,
    notes:
        'Machine jumps in 5 kg steps. Build reps first, or slow the '
        'tempo.',
  ),
  ExerciseDef(
    id: 'seated_calf_raise',
    name: 'Seated calf raise',
    muscle: MuscleGroup.calves,
    secondaryMuscles: const [],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
  ),
  ExerciseDef(
    id: 'dead_bug',
    alternativeIds: ['plank'],
    name: 'Dead bug',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.core,
    repsPerSide: true,
  ),
  ExerciseDef(
    id: 'cable_crunch',
    incrementKg: 6,
    alternativeIds: ['hanging_knee_raise', 'dead_bug'],
    name: 'Cable crunch',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [],
    equipment: Equipment.cable,
    effortClass: EffortClass.core,
    stackUnit: StackUnit.lb,
    notes: 'Weighted beats endless bodyweight crunches — overload it.',
  ),

  // ---- Stand-ins for when the machine or rack is taken ----------------
  ExerciseDef(
    id: 'pushup',
    name: 'Push-up',
    muscle: MuscleGroup.chest,
    secondaryMuscles: const [
      MuscleGroup.triceps,
      MuscleGroup.shoulders,
      MuscleGroup.core,
    ],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.moderateCompound,
    notes: 'Needs no equipment — the fallback when every bench is taken.',
  ),
  ExerciseDef(
    id: 'goblet_squat',
    name: 'Goblet squat',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [
      MuscleGroup.glutes,
      MuscleGroup.adductors,
      MuscleGroup.core,
    ],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.moderateCompound,
    incrementKg: 2.5,
    notes: 'One dumbbell held at the chest. Stands in for the leg press.',
  ),
  ExerciseDef(
    id: 'walking_lunge',
    name: 'Walking lunge',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [MuscleGroup.glutes, MuscleGroup.hamstrings],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.moderateCompound,
    loadIsPerSide: true,
    incrementKg: 2.5,
    repsPerSide: true,
  ),
  ExerciseDef(
    id: 'db_rdl',
    name: 'Dumbbell Romanian deadlift',
    muscle: MuscleGroup.hamstrings,
    secondaryMuscles: const [
      MuscleGroup.glutes,
      MuscleGroup.back,
      MuscleGroup.grip,
    ],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.moderateCompound,
    loadIsPerSide: true,
    incrementKg: 2.5,
    notes: 'Hip hinge — covers the hamstrings when the curl machine is busy.',
  ),
  ExerciseDef(
    id: 'side_lying_abduction',
    name: 'Side-lying hip abduction',
    muscle: MuscleGroup.abductors,
    secondaryMuscles: const [MuscleGroup.glutes],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.isolation,
    repsPerSide: true,
    notes: 'Floor version of the abductor machine.',
  ),

  // ---- The wider library ---------------------------------------------
  // Nothing below is on a routine. These exist so a swap always has a
  // sensible answer, and so the plan has somewhere to grow. Every one
  // names the movements it stands in for; those links read both ways, so
  // adding a variation here also gives the original a new stand-in.

  // Back and traps
  ExerciseDef(
    id: 'chin_up',
    alternativeIds: ['assisted_pullup', 'pullup_negative', 'lat_pulldown'],
    name: 'Chin-up',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.biceps,
      MuscleGroup.grip,
      MuscleGroup.shoulders,
    ],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.heavyCompound,
    notes:
        'Underhand grip lets the biceps help, so it usually arrives a '
        'month or two before the pull-up. Worth testing alongside it.',
  ),
  ExerciseDef(
    id: 'neutral_grip_pulldown',
    alternativeIds: ['lat_pulldown', 'assisted_pullup'],
    name: 'Neutral-grip pulldown',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.biceps, MuscleGroup.grip],
    equipment: Equipment.cable,
    effortClass: EffortClass.moderateCompound,
    stackUnit: StackUnit.lb,
    incrementKg: 6,
    notes:
        'Palms facing — the kindest grip on the elbows, and the '
        'closest pulldown to a chin-up.',
  ),
  ExerciseDef(
    id: 'barbell_row',
    alternativeIds: [
      'chest_supported_row',
      'single_arm_db_row',
      'seated_cable_row',
    ],
    name: 'Bent-over barbell row',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.biceps,
      MuscleGroup.shoulders,
      MuscleGroup.grip,
      MuscleGroup.hamstrings,
    ],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 20,
    incrementKg: 5,
    notes:
        'The heaviest row available, and the one that taxes the lower '
        'back — skip it on the back-sore variant of leg day.',
  ),
  ExerciseDef(
    id: 'single_arm_db_row',
    alternativeIds: ['chest_supported_row', 'seated_cable_row'],
    name: 'One-arm dumbbell row',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.biceps,
      MuscleGroup.grip,
      MuscleGroup.core,
    ],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.moderateCompound,
    repsPerSide: true,
    incrementKg: 2.5,
    notes:
        'One dumbbell, one side at a time — log the bell, not double '
        'it. Needs nothing but a bench, so it always frees up.',
  ),
  ExerciseDef(
    id: 'straight_arm_pulldown',
    alternativeIds: ['lat_pulldown', 'neutral_grip_pulldown'],
    name: 'Straight-arm pulldown',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.triceps, MuscleGroup.core],
    equipment: Equipment.cable,
    effortClass: EffortClass.isolation,
    stackUnit: StackUnit.lb,
    incrementKg: 6,
    notes:
        'Lats without the biceps, so it works on a day when the arms '
        'are the thing giving out first.',
  ),
  ExerciseDef(
    id: 'barbell_shrug',
    alternativeIds: ['db_shrug'],
    name: 'Barbell shrug',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.grip],
    equipment: Equipment.barbell,
    effortClass: EffortClass.isolation,
    barWeight: 20,
    incrementKg: 5,
    notes:
        'The direct trap work the back goal is missing. Straight up '
        'and down — rolling the shoulders adds nothing.',
  ),
  ExerciseDef(
    id: 'db_shrug',
    alternativeIds: ['barbell_shrug'],
    name: 'Dumbbell shrug',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.grip],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.isolation,
    loadIsPerSide: true,
    incrementKg: 2.5,
    notes:
        'Grip usually fails before the traps do — straps or a hook '
        'grip if it becomes the limit.',
  ),
  ExerciseDef(
    id: 'rack_pull',
    alternativeIds: ['barbell_row', 'db_rdl'],
    name: 'Rack pull',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.glutes,
      MuscleGroup.hamstrings,
      MuscleGroup.grip,
    ],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 20,
    incrementKg: 5,
    notes:
        'Partial deadlift from knee height. Builds mid-back thickness '
        'and traps at loads a full pull cannot hold yet.',
  ),

  // Biceps
  ExerciseDef(
    id: 'ez_bar_curl',
    alternativeIds: ['hammer_curl', 'incline_db_curl', 'cable_curl'],
    name: 'EZ-bar curl',
    muscle: MuscleGroup.biceps,
    secondaryMuscles: const [MuscleGroup.grip],
    equipment: Equipment.barbell,
    effortClass: EffortClass.isolation,
    barWeight: 10,
    incrementKg: 2.5,
    notes:
        'Both arms at once, so it loads heavier than dumbbells. Bar '
        'is 10 kg; the angled grip spares the wrists.',
  ),
  ExerciseDef(
    id: 'cable_curl',
    alternativeIds: ['hammer_curl', 'ez_bar_curl'],
    name: 'Cable curl',
    muscle: MuscleGroup.biceps,
    secondaryMuscles: const [MuscleGroup.grip],
    equipment: Equipment.cable,
    effortClass: EffortClass.isolation,
    stackUnit: StackUnit.lb,
    incrementKg: 6,
    notes: 'Tension stays on at the top, where a dumbbell goes slack.',
  ),
  ExerciseDef(
    id: 'preacher_curl',
    alternativeIds: ['incline_db_curl', 'ez_bar_curl'],
    name: 'Preacher curl',
    muscle: MuscleGroup.biceps,
    secondaryMuscles: const [],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    notes:
        'The pad removes the swing, so a bad set is obvious. Open '
        'item: confirm the stack step.',
  ),

  // Grip
  ExerciseDef(
    id: 'farmer_carry',
    alternativeIds: ['dead_hang'],
    name: "Farmer's carry",
    muscle: MuscleGroup.grip,
    secondaryMuscles: const [
      MuscleGroup.core,
      MuscleGroup.back,
      MuscleGroup.shoulders,
    ],
    equipment: Equipment.dumbbell,
    tracking: TrackingMode.duration,
    effortClass: EffortClass.isolation,
    loadIsPerSide: true,
    incrementKg: 2.5,
    notes:
        'Log the seconds carried. Grip work that does not fight the '
        'bar for hand skin the way hangs do.',
  ),
  ExerciseDef(
    id: 'towel_hang',
    alternativeIds: ['dead_hang'],
    name: 'Towel dead hang',
    muscle: MuscleGroup.grip,
    secondaryMuscles: const [MuscleGroup.back, MuscleGroup.shoulders],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.duration,
    effortClass: EffortClass.isolation,
    notes:
        'A towel over the bar, one end in each hand. Expect roughly '
        'half your bar-hang time.',
  ),

  // Chest
  ExerciseDef(
    id: 'flat_bb_bench',
    alternativeIds: ['db_bench', 'incline_bb_bench', 'machine_chest_press'],
    name: 'Flat barbell bench',
    muscle: MuscleGroup.chest,
    secondaryMuscles: const [MuscleGroup.triceps, MuscleGroup.shoulders],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 20,
    incrementKg: 5,
    notes:
        'The heaviest press here. Needs a spotter or safeties once it '
        'gets past the bar plus a plate.',
  ),
  ExerciseDef(
    id: 'incline_db_press',
    alternativeIds: ['incline_bb_bench', 'db_bench'],
    name: 'Incline dumbbell press',
    muscle: MuscleGroup.chest,
    secondaryMuscles: const [MuscleGroup.shoulders, MuscleGroup.triceps],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.moderateCompound,
    loadIsPerSide: true,
    incrementKg: 2.5,
    notes: 'Upper chest, without queuing for the incline barbell rack.',
  ),
  ExerciseDef(
    id: 'machine_chest_press',
    alternativeIds: ['db_bench', 'pushup', 'pec_deck'],
    name: 'Chest press machine',
    muscle: MuscleGroup.chest,
    secondaryMuscles: const [MuscleGroup.triceps, MuscleGroup.shoulders],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.moderateCompound,
    notes:
        'Fixed path, no balancing — the safe way to push chest close '
        'to failure alone. Open item: confirm the stack step.',
  ),
  ExerciseDef(
    id: 'incline_pushup',
    alternativeIds: ['pushup'],
    name: 'Incline push-up',
    muscle: MuscleGroup.chest,
    secondaryMuscles: const [
      MuscleGroup.triceps,
      MuscleGroup.shoulders,
      MuscleGroup.core,
    ],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.moderateCompound,
    notes:
        'Hands on a bench. The easier push-up — use it to keep reps '
        'honest at the end of a session rather than grinding halves.',
  ),

  // Shoulders
  ExerciseDef(
    id: 'ohp',
    alternativeIds: ['db_shoulder_press', 'machine_shoulder_press'],
    name: 'Overhead barbell press',
    muscle: MuscleGroup.shoulders,
    secondaryMuscles: const [MuscleGroup.triceps, MuscleGroup.core],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 20,
    incrementKg: 5,
    notes:
        'The one press the plan has no room for yet. Front delts and '
        'triceps, standing, so the core pays too.',
  ),
  ExerciseDef(
    id: 'db_shoulder_press',
    alternativeIds: ['ohp', 'machine_shoulder_press'],
    name: 'Dumbbell shoulder press',
    muscle: MuscleGroup.shoulders,
    secondaryMuscles: const [MuscleGroup.triceps],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.moderateCompound,
    loadIsPerSide: true,
    incrementKg: 2.5,
    notes: 'Seated with back support unless the core work is the point.',
  ),
  ExerciseDef(
    id: 'machine_shoulder_press',
    alternativeIds: ['db_shoulder_press', 'ohp'],
    name: 'Shoulder press machine',
    muscle: MuscleGroup.shoulders,
    secondaryMuscles: const [MuscleGroup.triceps],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.moderateCompound,
    notes: 'Open item: confirm the stack step.',
  ),
  ExerciseDef(
    id: 'cable_lateral_raise',
    alternativeIds: ['lateral_raise'],
    name: 'Cable lateral raise',
    muscle: MuscleGroup.shoulders,
    secondaryMuscles: const [],
    equipment: Equipment.cable,
    effortClass: EffortClass.isolation,
    stackUnit: StackUnit.lb,
    incrementKg: 6,
    repsPerSide: true,
    notes:
        'One arm at a time, cable behind the back. Hardest at the '
        'bottom, which is exactly where dumbbells are easiest.',
  ),
  ExerciseDef(
    id: 'reverse_pec_deck',
    alternativeIds: ['rear_delt_fly', 'face_pull'],
    name: 'Reverse pec deck',
    muscle: MuscleGroup.shoulders,
    secondaryMuscles: const [MuscleGroup.back],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    notes:
        'Rear delts with no way to cheat by swinging. Same machine as '
        'the pec deck, seat turned around.',
  ),

  // Triceps
  ExerciseDef(
    id: 'assisted_dip',
    alternativeIds: ['bench_dip', 'close_grip_bench', 'rope_pushdown'],
    name: 'Assisted dip',
    muscle: MuscleGroup.triceps,
    secondaryMuscles: const [MuscleGroup.chest, MuscleGroup.shoulders],
    equipment: Equipment.assisted,
    loadSemantics: LoadSemantics.assistanceInverted,
    effortClass: EffortClass.heavyCompound,
    incrementKg: 5,
    notes:
        'The same machine as the assisted pull-up, so it costs no '
        'extra queueing. Lower assistance = harder.',
  ),
  ExerciseDef(
    id: 'bench_dip',
    alternativeIds: ['assisted_dip', 'pushup'],
    name: 'Bench dip',
    muscle: MuscleGroup.triceps,
    secondaryMuscles: const [MuscleGroup.chest, MuscleGroup.shoulders],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.moderateCompound,
    notes:
        'Hands behind on a bench. Rough on the shoulders if you sink '
        'too deep — stop at upper arms parallel.',
  ),
  ExerciseDef(
    id: 'skullcrusher',
    alternativeIds: ['oh_db_extension', 'rope_pushdown', 'close_grip_bench'],
    name: 'EZ-bar skullcrusher',
    muscle: MuscleGroup.triceps,
    secondaryMuscles: const [],
    equipment: Equipment.barbell,
    effortClass: EffortClass.isolation,
    barWeight: 10,
    incrementKg: 2.5,
    notes:
        'Stretches the long head, which pushdowns barely touch. Elbows '
        'complain if you rush it.',
  ),

  // Quads
  ExerciseDef(
    id: 'back_squat',
    alternativeIds: ['hack_squat', 'leg_press', 'goblet_squat'],
    name: 'Barbell back squat',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [
      MuscleGroup.glutes,
      MuscleGroup.hamstrings,
      MuscleGroup.core,
    ],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 20,
    incrementKg: 5,
    notes:
        'The heavy compound the bigger-legs goal is waiting on. Start '
        'lighter than pride suggests and learn the groove.',
  ),
  ExerciseDef(
    id: 'hack_squat',
    alternativeIds: ['leg_press', 'back_squat'],
    name: 'Hack squat',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [MuscleGroup.glutes, MuscleGroup.adductors],
    equipment: Equipment.machinePlateLoaded,
    effortClass: EffortClass.heavyCompound,
    incrementKg: 10,
    notes:
        'Squat pattern with the back supported. Log the plates you '
        'add — the carriage weight is unknown.',
  ),
  ExerciseDef(
    id: 'step_up',
    alternativeIds: ['bulgarian_split_squat', 'walking_lunge'],
    name: 'Dumbbell step-up',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [
      MuscleGroup.glutes,
      MuscleGroup.hamstrings,
      MuscleGroup.core,
    ],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.moderateCompound,
    loadIsPerSide: true,
    repsPerSide: true,
    incrementKg: 2.5,
    notes:
        'Push through the top foot and do not bounce off the bottom '
        'one. Box at knee height.',
  ),
  ExerciseDef(
    id: 'reverse_lunge',
    alternativeIds: ['walking_lunge', 'bulgarian_split_squat'],
    name: 'Reverse lunge',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [MuscleGroup.glutes, MuscleGroup.hamstrings],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.moderateCompound,
    loadIsPerSide: true,
    repsPerSide: true,
    incrementKg: 2.5,
    notes:
        'Kinder on the knees than a walking lunge, and it needs one '
        'square metre instead of a clear aisle.',
  ),
  ExerciseDef(
    id: 'wall_sit',
    alternativeIds: ['leg_extension', 'goblet_squat'],
    name: 'Wall sit',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.duration,
    effortClass: EffortClass.isolation,
    notes:
        'Needs a wall and nothing else — the last resort when every '
        'leg machine is taken.',
  ),

  // Hamstrings and glutes
  ExerciseDef(
    id: 'seated_leg_curl',
    alternativeIds: ['lying_leg_curl', 'db_rdl'],
    name: 'Seated leg curl',
    muscle: MuscleGroup.hamstrings,
    secondaryMuscles: const [MuscleGroup.calves],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    incrementKg: 5,
    notes:
        'Hips bent, so the hamstrings start stretched — it trains a '
        'different part of the range than the lying curl.',
  ),
  ExerciseDef(
    id: 'bb_rdl',
    alternativeIds: ['db_rdl', 'lying_leg_curl', 'rack_pull'],
    name: 'Barbell Romanian deadlift',
    muscle: MuscleGroup.hamstrings,
    secondaryMuscles: const [
      MuscleGroup.glutes,
      MuscleGroup.back,
      MuscleGroup.grip,
    ],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 20,
    incrementKg: 5,
    notes:
        'The hip hinge the leg day is missing. Loads far past what '
        'dumbbells allow, and taxes the lower back to match.',
  ),
  ExerciseDef(
    id: 'back_extension',
    alternativeIds: ['db_rdl', 'bb_rdl'],
    name: '45° back extension',
    muscle: MuscleGroup.hamstrings,
    secondaryMuscles: const [MuscleGroup.glutes, MuscleGroup.back],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.isolation,
    notes:
        'Hinge at the hips with a flat back. Hold a plate at the chest '
        'once bodyweight stops being work.',
  ),
  ExerciseDef(
    id: 'hip_thrust',
    alternativeIds: ['glute_bridge', 'cable_pull_through', 'leg_press'],
    name: 'Barbell hip thrust',
    muscle: MuscleGroup.glutes,
    secondaryMuscles: const [MuscleGroup.hamstrings, MuscleGroup.quads],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 20,
    incrementKg: 5,
    notes:
        'Nothing in the routine trains glutes as the main job — this '
        'is the movement that does, and it feeds the outer-hip goal.',
  ),
  ExerciseDef(
    id: 'glute_bridge',
    alternativeIds: ['hip_thrust'],
    name: 'Glute bridge',
    muscle: MuscleGroup.glutes,
    secondaryMuscles: const [MuscleGroup.hamstrings],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.isolation,
    notes:
        'Floor version, no bench or bar. Squeeze at the top for a '
        'second rather than chasing reps.',
  ),
  ExerciseDef(
    id: 'cable_pull_through',
    alternativeIds: ['hip_thrust', 'db_rdl'],
    name: 'Cable pull-through',
    muscle: MuscleGroup.glutes,
    secondaryMuscles: const [MuscleGroup.hamstrings, MuscleGroup.back],
    equipment: Equipment.cable,
    effortClass: EffortClass.isolation,
    stackUnit: StackUnit.lb,
    incrementKg: 6,
    notes:
        'A hinge the lower back barely notices — the one to keep on '
        'the back-sore variant of leg day.',
  ),

  // Calves
  ExerciseDef(
    id: 'standing_calf_raise',
    alternativeIds: ['seated_calf_raise', 'single_leg_calf_raise'],
    name: 'Standing calf raise',
    muscle: MuscleGroup.calves,
    secondaryMuscles: const [],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    notes:
        'Knees straight, which loads the gastrocnemius — the seated '
        'version cannot reach it.',
  ),
  ExerciseDef(
    id: 'single_leg_calf_raise',
    alternativeIds: ['seated_calf_raise', 'standing_calf_raise'],
    name: 'Single-leg calf raise',
    muscle: MuscleGroup.calves,
    secondaryMuscles: const [],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.isolation,
    repsPerSide: true,
    notes:
        'Off a step for the full stretch. Needs a stair and nothing '
        'else.',
  ),

  // Hips
  ExerciseDef(
    id: 'cable_hip_abduction',
    alternativeIds: [
      'hip_abductor',
      'side_lying_abduction',
      'banded_lateral_walk',
    ],
    name: 'Cable hip abduction',
    muscle: MuscleGroup.abductors,
    secondaryMuscles: const [MuscleGroup.glutes],
    equipment: Equipment.cable,
    effortClass: EffortClass.isolation,
    stackUnit: StackUnit.lb,
    incrementKg: 6,
    repsPerSide: true,
    notes:
        'Ankle strap, standing. Loads the outer hip through a longer '
        'range than the seated machine.',
  ),
  ExerciseDef(
    id: 'banded_lateral_walk',
    alternativeIds: ['side_lying_abduction', 'hip_abductor'],
    name: 'Lateral band walk',
    muscle: MuscleGroup.abductors,
    secondaryMuscles: const [MuscleGroup.glutes],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.isolation,
    repsPerSide: true,
    notes:
        'Band around the knees, small steps, tension never released. '
        'Count steps each way.',
  ),
  ExerciseDef(
    id: 'copenhagen_plank',
    alternativeIds: ['hip_adductor', 'cossack_squat'],
    name: 'Copenhagen plank',
    muscle: MuscleGroup.adductors,
    secondaryMuscles: const [MuscleGroup.core],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.duration,
    effortClass: EffortClass.isolation,
    repsPerSide: true,
    notes:
        'Top leg on a bench, side plank on the bottom arm. Start with '
        'the bottom knee bent — it is much harder than it looks.',
  ),
  ExerciseDef(
    id: 'cossack_squat',
    alternativeIds: ['hip_adductor', 'copenhagen_plank'],
    name: 'Cossack squat',
    muscle: MuscleGroup.adductors,
    secondaryMuscles: const [MuscleGroup.quads, MuscleGroup.glutes],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.moderateCompound,
    repsPerSide: true,
    notes:
        'Inner thigh through a deep stretch, and it doubles as hip '
        'mobility work.',
  ),

  // Core
  ExerciseDef(
    id: 'hanging_leg_raise',
    alternativeIds: ['hanging_knee_raise', 'cable_crunch'],
    name: 'Hanging leg raise',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [MuscleGroup.grip, MuscleGroup.back],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.core,
    notes:
        'Straight legs — the step up from knee raises, and more grip '
        'work on the way.',
  ),
  ExerciseDef(
    id: 'ab_crunch_machine',
    alternativeIds: ['cable_crunch', 'hanging_knee_raise', 'ab_wheel'],
    name: 'Ab crunch machine',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.core,
    notes:
        'Seated, back supported, load on a stack — the easiest way to '
        'add weight to a crunch and actually progress it. Curl the ribs '
        'down rather than folding at the hips. Open item: confirm the '
        'stack step.',
  ),
  ExerciseDef(
    id: 'ab_wheel',
    alternativeIds: ['plank', 'hanging_knee_raise'],
    name: 'Ab wheel rollout',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [MuscleGroup.shoulders, MuscleGroup.back],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.bodyweightReps,
    effortClass: EffortClass.core,
    notes:
        'From the knees, ribs down. A plank that actually gets harder '
        'as you get better at it.',
  ),
  ExerciseDef(
    id: 'side_plank',
    alternativeIds: ['plank', 'pallof_press'],
    name: 'Side plank',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [MuscleGroup.abductors, MuscleGroup.shoulders],
    equipment: Equipment.bodyweight,
    loadSemantics: LoadSemantics.bodyweightOnly,
    tracking: TrackingMode.duration,
    effortClass: EffortClass.core,
    repsPerSide: true,
    notes:
        'Trains the side of the trunk the front plank ignores, and '
        'the outer hip along with it.',
  ),
  // Machines. A stack is the easiest thing in the gym to progress — the
  // pin moves and nothing about the movement changes — and it is what
  // stays available when the free-weight area is full.
  ExerciseDef(
    id: 'machine_row',
    alternativeIds: ['chest_supported_row', 'seated_cable_row'],
    name: 'Seated row machine',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.biceps, MuscleGroup.shoulders],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.moderateCompound,
    notes:
        'Chest pad takes the lower back out of it. Open item: confirm '
        'the stack step.',
  ),
  ExerciseDef(
    id: 't_bar_row',
    alternativeIds: ['chest_supported_row', 'barbell_row'],
    name: 'T-bar row',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [
      MuscleGroup.biceps,
      MuscleGroup.shoulders,
      MuscleGroup.grip,
    ],
    equipment: Equipment.machinePlateLoaded,
    effortClass: EffortClass.heavyCompound,
    incrementKg: 5,
    notes:
        'Loads heavy like a barbell row with the chest supported. Log '
        'the plates you hang on it.',
  ),
  ExerciseDef(
    id: 'plate_loaded_pulldown',
    alternativeIds: ['lat_pulldown', 'assisted_pullup'],
    name: 'Iso-lateral pulldown',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.biceps, MuscleGroup.grip],
    equipment: Equipment.machinePlateLoaded,
    effortClass: EffortClass.moderateCompound,
    loadIsPerSide: true,
    incrementKg: 5,
    notes:
        'Each arm on its own handle, so the strong side cannot cover '
        'for the weak one. Log the plates per side.',
  ),
  ExerciseDef(
    id: 'machine_shrug',
    alternativeIds: ['barbell_shrug', 'db_shrug'],
    name: 'Shrug machine',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.grip],
    equipment: Equipment.machinePlateLoaded,
    effortClass: EffortClass.isolation,
    incrementKg: 5,
    notes:
        'Handles at the sides, so nothing balances and the traps just '
        'work. The easiest shrug to load heavily.',
  ),
  ExerciseDef(
    id: 'machine_back_extension',
    alternativeIds: ['back_extension', 'cable_pull_through'],
    name: 'Back extension machine',
    muscle: MuscleGroup.back,
    secondaryMuscles: const [MuscleGroup.glutes, MuscleGroup.hamstrings],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    notes:
        'Seated, pad against the upper back. Trains the spinal '
        'erectors with a load you can actually dial in — kinder than the '
        '45° bench on a sore lower back.',
  ),
  ExerciseDef(
    id: 'machine_lateral_raise',
    alternativeIds: ['lateral_raise', 'cable_lateral_raise'],
    name: 'Lateral raise machine',
    muscle: MuscleGroup.shoulders,
    secondaryMuscles: const [],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    notes:
        'Pads on the upper arms, so there is no way to swing it into a '
        'shrug the way dumbbells invite. Open item: confirm the stack '
        'step.',
  ),
  ExerciseDef(
    id: 'machine_triceps_extension',
    alternativeIds: ['rope_pushdown', 'oh_db_extension', 'skullcrusher'],
    name: 'Triceps extension machine',
    muscle: MuscleGroup.triceps,
    secondaryMuscles: const [],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    notes:
        'Elbows fixed on a pad. The one triceps movement where a bad '
        'set is impossible to fake with the shoulders.',
  ),
  ExerciseDef(
    id: 'seated_leg_press',
    alternativeIds: ['leg_press', 'hack_squat'],
    name: 'Seated leg press',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [MuscleGroup.glutes, MuscleGroup.adductors],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.heavyCompound,
    notes:
        'The horizontal stack version — no plates to load, so it is '
        'the quickest heavy quad work in the building.',
  ),
  ExerciseDef(
    id: 'smith_squat',
    alternativeIds: ['back_squat', 'hack_squat', 'leg_press'],
    name: 'Smith machine squat',
    muscle: MuscleGroup.quads,
    secondaryMuscles: const [
      MuscleGroup.glutes,
      MuscleGroup.hamstrings,
      MuscleGroup.core,
    ],
    equipment: Equipment.barbell,
    effortClass: EffortClass.heavyCompound,
    barWeight: 15,
    incrementKg: 5,
    notes:
        'Fixed bar path with catches at every height, so it is the '
        'squat you can push alone. Bar is lighter than a free one — '
        'roughly 15 kg here.',
  ),
  ExerciseDef(
    id: 'calf_press',
    alternativeIds: ['seated_calf_raise', 'standing_calf_raise'],
    name: 'Calf press on the leg press',
    muscle: MuscleGroup.calves,
    secondaryMuscles: const [],
    equipment: Equipment.machinePlateLoaded,
    effortClass: EffortClass.machineIsolation,
    baseLoadKg: 40,
    incrementKg: 10,
    notes:
        'Same sled as the leg press — 40 kg before you add anything. '
        'Balls of the feet at the bottom edge, full stretch each rep.',
  ),
  ExerciseDef(
    id: 'machine_hip_thrust',
    alternativeIds: ['hip_thrust', 'glute_bridge'],
    name: 'Hip thrust machine',
    muscle: MuscleGroup.glutes,
    secondaryMuscles: const [MuscleGroup.hamstrings, MuscleGroup.quads],
    equipment: Equipment.machinePlateLoaded,
    effortClass: EffortClass.moderateCompound,
    incrementKg: 5,
    notes:
        'All of the barbell hip thrust without rolling a loaded bar '
        'over your hips. If the gym has one, use it.',
  ),
  ExerciseDef(
    id: 'glute_kickback_machine',
    alternativeIds: ['hip_thrust', 'cable_pull_through'],
    name: 'Glute kickback machine',
    muscle: MuscleGroup.glutes,
    secondaryMuscles: const [MuscleGroup.hamstrings],
    equipment: Equipment.machineStack,
    effortClass: EffortClass.machineIsolation,
    repsPerSide: true,
    notes:
        'One leg at a time. Isolation rather than a hinge, so it goes '
        'after the heavy work, not before it.',
  ),
  ExerciseDef(
    id: 'russian_twist',
    alternativeIds: ['pallof_press', 'dead_bug'],
    name: 'Russian twist',
    muscle: MuscleGroup.core,
    secondaryMuscles: const [],
    equipment: Equipment.dumbbell,
    effortClass: EffortClass.core,
    repsPerSide: true,
    incrementKg: 2.5,
    notes:
        'One dumbbell held at the chest. Rotate from the ribs, not by '
        'swinging the arms.',
  ),
];

// ----------------------------------------------------------------------- plan

/// Weekly rotation:
///   Mon Pull · Tue Push · Wed Legs · Thu rest ·
///   Fri Pull · Sat Push *or* Legs · Sun rest
TrainingPlan seedPlan() => TrainingPlan(
  name: 'Pull / Push / Legs rotation',
  days: [
    PlanDay(
      id: 'day_pull',
      name: 'Pull Day',
      focus: 'Back · Biceps · Grip',
      weekdays: {DateTime.monday, DateTime.friday},
      goalIds: const ['G1', 'G3', 'G6'],
      warmup:
          'Band pull-aparts 2×15 · shoulder circles / band dislocates '
          '2×10 · light lat pulldown 1×15 @ 12 kg',
      notes:
          'Curls live at the end of pull day, never on their own day — '
          'sore biceps going into pull work costs more than it gives.',
      items: [
        PlanItem(
          exerciseId: 'pullup_negative',
          sets: 4,
          repMin: 5,
          repMax: 5,
          restSeconds: 150,
          notes:
              'Duration stuck at 2 s for 3 sessions — try the assist '
              'machine at 25–30 kg assistance to allow 4–5 s.',
        ),
        PlanItem(
          exerciseId: 'scap_pullup',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 90,
          notes: 'Add reps or a 1 s hold at the bottom.',
        ),
        PlanItem(
          exerciseId: 'assisted_pullup',
          sets: 4,
          repMin: 10,
          repMax: 10,
          targetWeight: 55,
          restSeconds: 150,
          notes:
              'Lower = harder. Drop to 50 kg when 4×10 stops being a '
              'fight.',
        ),
        PlanItem(
          exerciseId: 'lat_pulldown',
          sets: 3,
          repMin: 12,
          repMax: 15,
          targetWeight: 24,
          restSeconds: 90,
          notes: '3 sessions at all reps — ready to increase.',
        ),
        PlanItem(
          exerciseId: 'chest_supported_row',
          sets: 3,
          repMin: 10,
          repMax: 13,
          targetWeight: 20,
          restSeconds: 90,
          notes: 'Track plates only — base resistance is unknown.',
        ),
        PlanItem(
          exerciseId: 'seated_cable_row',
          sets: 3,
          repMin: 15,
          repMax: 18,
          targetWeight: 18,
          restSeconds: 90,
          notes:
              'Hit 3×15 — next session jump to 24 kg and expect 8–10 '
              'reps.',
        ),
        PlanItem(
          exerciseId: 'hammer_curl',
          sets: 3,
          repMin: 10,
          repMax: 12,
          targetWeight: 7.5,
          restSeconds: 60,
          notes: 'Build back to 3×12.',
        ),
        PlanItem(
          exerciseId: 'incline_db_curl',
          sets: 3,
          repMin: 12,
          repMax: 15,
          targetWeight: 5,
          restSeconds: 60,
        ),
        PlanItem(
          exerciseId: 'dead_hang',
          sets: 3,
          repMin: 30,
          repMax: 60,
          restSeconds: 60,
          notes: 'Near failure each set. 30 s okay, 60 s solid.',
        ),
        PlanItem(
          exerciseId: 'inverted_row',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 90,
          active: false,
          notes: 'Swapped out for the chest-supported row.',
        ),
      ],
    ),
    PlanDay(
      id: 'day_push',
      name: 'Push Day',
      focus: 'Chest · Shoulders · Triceps · Core',
      weekdays: {DateTime.tuesday, DateTime.saturday},
      goalIds: const ['G3', 'G4'],
      warmup:
          'Light cardio · band pull-aparts 2×15 · 1 light set of the '
          'first press',
      notes:
          'Triceps go at the end, after all pressing. Core is folded in '
          'here rather than getting its own day.',
      items: [
        PlanItem(
          exerciseId: 'db_bench',
          sets: 4,
          repMin: 10,
          repMax: 13,
          targetWeight: 7.5,
          restSeconds: 90,
          notes: 'Cleared 4×10 — ready to try 10 kg/hand.',
        ),
        PlanItem(
          exerciseId: 'incline_bb_bench',
          sets: 3,
          repMin: 10,
          repMax: 13,
          targetWeight: 20,
          restSeconds: 150,
          notes: 'Empty bar now — try 25 kg (+2.5 kg per side).',
        ),
        PlanItem(
          exerciseId: 'pec_deck',
          sets: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 60,
          notes: 'Working weight not yet established.',
        ),
        PlanItem(
          exerciseId: 'lateral_raise',
          sets: 4,
          repMin: 12,
          repMax: 15,
          targetWeight: 5,
          restSeconds: 60,
          notes: 'Build to 15 reps before adding weight.',
        ),
        PlanItem(
          exerciseId: 'rear_delt_fly',
          sets: 3,
          repMin: 15,
          repMax: 18,
          restSeconds: 60,
          notes: 'Light. Weight not yet established.',
        ),
        PlanItem(
          exerciseId: 'face_pull',
          sets: 3,
          repMin: 15,
          repMax: 18,
          targetWeight: 18,
          restSeconds: 60,
        ),
        PlanItem(
          exerciseId: 'close_grip_bench',
          sets: 3,
          repMin: 10,
          repMax: 13,
          targetWeight: 20,
          restSeconds: 150,
          notes: 'Empty bar now — try 25 kg.',
        ),
        PlanItem(
          exerciseId: 'rope_pushdown',
          sets: 3,
          repMin: 12,
          repMax: 15,
          targetWeight: 18.3,
          restSeconds: 60,
        ),
        PlanItem(
          exerciseId: 'hanging_knee_raise',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 40,
        ),
        PlanItem(
          exerciseId: 'pallof_press',
          sets: 3,
          repMin: 12,
          repMax: 15,
          restSeconds: 40,
          notes: 'Per side.',
        ),
        PlanItem(
          exerciseId: 'plank',
          sets: 3,
          repMin: 30,
          repMax: 45,
          restSeconds: 40,
        ),
        PlanItem(
          exerciseId: 'oh_db_extension',
          sets: 4,
          repMin: 12,
          repMax: 15,
          targetWeight: 5,
          restSeconds: 60,
          active: false,
          notes: 'Not yet logged — fold in if triceps need more volume.',
        ),
      ],
    ),
    PlanDay(
      id: 'day_legs',
      name: 'Leg Day',
      focus: 'Quads · Hips · Hamstrings · Core',
      weekdays: {DateTime.wednesday, DateTime.saturday},
      goalIds: const ['G2', 'G4'],
      warmup: '5–10 min bike',
      notes:
          'Back-sore variant: drop Bulgarian split squats, keep '
          'everything seated or supported, bike instead of stair climber, '
          'and keep the lower back flat on the leg press pad.',
      items: [
        PlanItem(
          exerciseId: 'leg_press',
          sets: 4,
          repMin: 12,
          repMax: 15,
          targetWeight: 50,
          restSeconds: 150,
          notes:
              'Hold until 4×15, then +10 kg. 50 kg plates + 40 kg sled '
              '= 90 kg total.',
        ),
        PlanItem(
          exerciseId: 'bulgarian_split_squat',
          sets: 3,
          repMin: 8,
          repMax: 12,
          restSeconds: 90,
          notes: 'Build to 10–12 before adding dumbbells.',
        ),
        PlanItem(
          exerciseId: 'hip_abductor',
          sets: 4,
          repMin: 15,
          repMax: 18,
          targetWeight: 40,
          restSeconds: 60,
          notes:
              'Priority for outer-thigh balance. A struggle at 15 right '
              'now — hold the weight.',
        ),
        PlanItem(
          exerciseId: 'hip_adductor',
          sets: 4,
          repMin: 12,
          repMax: 15,
          targetWeight: 30,
          restSeconds: 60,
          notes: 'Keep slightly behind the abductor.',
        ),
        PlanItem(
          exerciseId: 'leg_extension',
          sets: 4,
          repMin: 12,
          repMax: 15,
          targetWeight: 22.5,
          restSeconds: 60,
          notes: 'Build to 4×15 before taking the 27 kg jump.',
        ),
        PlanItem(
          exerciseId: 'lying_leg_curl',
          sets: 4,
          repMin: 12,
          repMax: 15,
          targetWeight: 20,
          restSeconds: 60,
          notes: 'Build to 4×15 first, or slow the tempo.',
        ),
        PlanItem(
          exerciseId: 'seated_calf_raise',
          sets: 3,
          repMin: 15,
          repMax: 20,
          restSeconds: 60,
          notes: 'Optional.',
        ),
        PlanItem(
          exerciseId: 'dead_bug',
          sets: 3,
          repMin: 10,
          repMax: 13,
          restSeconds: 40,
          notes: 'Per side.',
        ),
        PlanItem(
          exerciseId: 'cable_crunch',
          sets: 3,
          repMin: 10,
          repMax: 12,
          restSeconds: 40,
        ),
      ],
    ),
  ],
);

// ---------------------------------------------------------------------- goals

List<Goal> seedGoals() => [
  Goal(
    id: 'G1',
    code: 'G1',
    title: 'First unassisted pull-up',
    type: GoalType.strengthMilestone,
    target: '1 clean rep at bodyweight',
    status: GoalStatus.active,
    primary: true,
    testExerciseId: 'unassisted_pullup',
    testIntervalDays: 14,
    notes:
        'Current effective pull ≈ 25 kg (80 kg bodyweight − 55 kg '
        'assistance) ≈ 31% of bodyweight; a typical untrained male starts '
        'nearer 50%, so the timeline is longer. Estimated 8–14 months at '
        '2×/week, toward 8 at 3×/week. Assist-machine numbers are '
        'approximate — the machine helps most at the bottom, so the true '
        'ratio is likely a bit higher. Test one honest unassisted attempt '
        'every 2 weeks, not every session.',
    markers: [
      GoalMarker(
        label: 'Unassisted reps',
        metric: MarkerMetric.topReps,
        exerciseId: 'unassisted_pullup',
        baseline: 0,
      ),
      GoalMarker(
        label: 'Assistance weight',
        metric: MarkerMetric.topLoad,
        exerciseId: 'assisted_pullup',
        baseline: 55,
        lowerIsBetter: true,
        unit: 'kg',
      ),
      GoalMarker(
        label: 'Negative duration',
        metric: MarkerMetric.topTempo,
        exerciseId: 'pullup_negative',
        baseline: 2,
        unit: 's',
      ),
      GoalMarker(
        label: 'Scapular pull-up reps',
        metric: MarkerMetric.topReps,
        exerciseId: 'scap_pullup',
        baseline: 8,
      ),
      GoalMarker(
        label: 'Lat pulldown',
        metric: MarkerMetric.topLoad,
        exerciseId: 'lat_pulldown',
        baseline: 24,
        unit: 'kg',
      ),
      GoalMarker(
        label: 'Bodyweight',
        metric: MarkerMetric.bodyweight,
        baseline: 80,
        lowerIsBetter: true,
        unit: 'kg',
      ),
    ],
    milestones: [
      Milestone(label: '5 s negatives', eta: '~1–2 months'),
      Milestone(label: 'Assistance down to 40 kg', eta: '~3–4 months'),
      Milestone(
        label: 'Assistance 25–30 kg + first partials',
        eta: '~6 months',
      ),
      Milestone(label: 'First unassisted rep', eta: '~8–12 months'),
    ],
  ),
  Goal(
    id: 'G2',
    code: 'G2',
    title: 'Balance outer thigh / hip against inner thigh',
    type: GoalType.physique,
    target: 'Visual balance',
    status: GoalStatus.active,
    notes:
        'Fat cannot be spot-reduced — inner-thigh size follows overall '
        'body fat. The actionable part is building the outer hip and thigh '
        '(abductors, glute medius) so the proportions balance.',
  ),
  Goal(
    id: 'G3',
    code: 'G3',
    title: 'Bigger arms',
    type: GoalType.physique,
    status: GoalStatus.active,
    notes:
        'Triceps are roughly two-thirds of upper-arm mass, so they get '
        'more volume than biceps.',
  ),
  Goal(
    id: 'G4',
    code: 'G4',
    title: 'Core strength',
    type: GoalType.general,
    status: GoalStatus.active,
    notes: 'Folded into push and leg days. No standalone abs day.',
  ),
  Goal(
    id: 'G5',
    code: 'G5',
    title: 'Bigger legs',
    type: GoalType.physique,
    target: 'Increased quad, hamstring and glute size',
    status: GoalStatus.queued,
    notes:
        'Would need a heavy compound at the front (squat / hack squat / '
        'heavy leg press at 5–8 reps), a hip hinge for hamstrings, and '
        'roughly 10–20 hard sets per muscle per week — which likely means '
        'legs 2×/week. Conflict: legs 2× and pull 2× is 4 committed slots, '
        'so push probably drops to 1×.',
  ),
  Goal(
    id: 'G6',
    code: 'G6',
    title: 'Muscly back',
    type: GoalType.physique,
    target: 'Visible lat width and mid-back thickness',
    status: GoalStatus.queued,
    notes:
        'Largely aligned with the pull-up goal. Gaps: direct trap work '
        '(shrugs or rack pulls), and a vertical pull variant once '
        'unassisted pull-ups arrive. Rows build thickness, pulldowns build '
        'width — the current day already has both.',
  ),
  Goal(
    id: 'G7',
    code: 'G7',
    title: 'Visible abs',
    type: GoalType.physique,
    status: GoalStatus.queued,
    notes:
        'Two components, and only one is training. Ab size responds to '
        'progressive overload; visibility is driven by body fat. Building '
        'strength and losing fat pull against each other, so the sensible '
        'sequence is muscle first (G3, G5, G6), then a gradual fat-loss '
        'phase.',
  ),
];
