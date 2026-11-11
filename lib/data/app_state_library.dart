part of 'app_state.dart';

/// The exercise library and the routines built out of it.
///
/// Everything here edits what training *should* look like, as opposed to
/// what happened: definitions, routines, and the slots inside them.
extension LibraryAndPlan on AppState {
  ExerciseDef exerciseById(String id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return ExerciseDef(id: id, name: 'Unknown exercise');
  }

  String exerciseName(String id) => exerciseById(id).name;

  List<ExerciseDef> get exercisesSorted {
    final list = [...exercises];
    list.sort((a, b) {
      final m = a.muscle.index.compareTo(b.muscle.index);
      return m != 0 ? m : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  ExerciseDef addExercise(
    String name,
    MuscleGroup muscle,
    Equipment equipment,
  ) {
    final ex = ExerciseDef(
      name: name.trim(),
      muscle: muscle,
      equipment: equipment,
      tracking: equipment == Equipment.bodyweight
          ? TrackingMode.bodyweightReps
          : TrackingMode.weightReps,
      loadSemantics: switch (equipment) {
        Equipment.assisted => LoadSemantics.assistanceInverted,
        Equipment.bodyweight => LoadSemantics.bodyweightOnly,
        _ => LoadSemantics.normal,
      },
      effortClass: muscle == MuscleGroup.core
          ? EffortClass.core
          : EffortClass.isolation,
      loadIsPerSide: equipment == Equipment.dumbbell,
      barWeight: equipment == Equipment.barbell ? 20 : 0,
    );
    exercises.add(ex);
    _touch();
    return ex;
  }

  void updateExercise(
    ExerciseDef ex, {
    String? name,
    MuscleGroup? muscle,
    Equipment? equipment,
    LoadSemantics? loadSemantics,
    TrackingMode? tracking,
    EffortClass? effortClass,
    double? baseLoadKg,
    bool clearBaseLoad = false,
    double? incrementKg,
    bool clearIncrement = false,
    StackUnit? stackUnit,
    bool? loadIsPerSide,
    bool? repsPerSide,
    double? barWeight,
    String? notes,
  }) {
    if (name != null && name.trim().isNotEmpty) ex.name = name.trim();
    if (muscle != null) ex.muscle = muscle;
    if (equipment != null) ex.equipment = equipment;
    if (loadSemantics != null) ex.loadSemantics = loadSemantics;
    if (tracking != null) ex.tracking = tracking;
    if (effortClass != null) ex.effortClass = effortClass;
    if (clearBaseLoad) {
      ex.baseLoadKg = null;
    } else if (baseLoadKg != null) {
      ex.baseLoadKg = baseLoadKg;
    }
    if (clearIncrement) {
      ex.incrementKg = null;
    } else if (incrementKg != null && incrementKg > 0) {
      // A step of nothing would "progress" to the same load forever.
      ex.incrementKg = incrementKg;
    }
    if (stackUnit != null) ex.stackUnit = stackUnit;
    if (loadIsPerSide != null) ex.loadIsPerSide = loadIsPerSide;
    if (repsPerSide != null) ex.repsPerSide = repsPerSide;
    // No bar weighs nothing, and 0 already means "never set".
    if (barWeight != null && barWeight > 0) ex.barWeight = barWeight;
    if (notes != null) ex.notes = notes;
    _touch();
  }

  /// Removes the movement from the library and from every routine. Logged
  /// history keeps its reference so past sessions still read correctly.
  void deleteExercise(String id) {
    exercises.removeWhere((e) => e.id == id);
    for (final d in plan.days) {
      d.items.removeWhere((i) => i.exerciseId == id);
    }
    // Nothing should offer a stand-in that no longer exists.
    for (final e in exercises) {
      e.alternativeIds.remove(id);
    }
    // Remembered so a later version does not ship it straight back.
    if (!settings.removedExerciseIds.contains(id)) {
      settings.removedExerciseIds.add(id);
    }
    _touch();
  }

  // --------------------------------------------------------------------- plan

  void renamePlan(String name) {
    if (name.trim().isNotEmpty) plan.name = name.trim();
    _touch();
  }

  PlanDay addDay(String name) {
    final day = PlanDay(name: name.trim().isEmpty ? 'New day' : name.trim());
    plan.days.add(day);
    _touch();
    return day;
  }

  void updateDay(
    PlanDay day, {
    String? name,
    String? focus,
    String? warmup,
    String? notes,
  }) {
    if (name != null && name.trim().isNotEmpty) day.name = name.trim();
    if (focus != null) day.focus = focus.trim();
    if (warmup != null) day.warmup = warmup.trim();
    if (notes != null) day.notes = notes.trim();
    _touch();
  }

  /// Weekdays are a set: pull day legitimately sits on two of them.
  void toggleWeekday(PlanDay day, int weekday) {
    if (!day.weekdays.remove(weekday)) day.weekdays.add(weekday);
    _touch();
  }

  void deleteDay(String dayId) {
    plan.days.removeWhere((d) => d.id == dayId);
    _touch();
  }

  void reorderDays(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    plan.days.insert(newIndex, plan.days.removeAt(oldIndex));
    _touch();
  }

  PlanItem addPlanItem(PlanDay day, String exerciseId) {
    final def = exerciseById(exerciseId);
    final item = PlanItem(
      exerciseId: exerciseId,
      restSeconds: def.effortClass.restSeconds,
      repMin: def.tracking == TrackingMode.duration ? 30 : 8,
      repMax: def.tracking == TrackingMode.duration ? 45 : 12,
    );
    day.items.add(item);
    _touch();
    return item;
  }

  void updatePlanItem(
    PlanItem item, {
    int? sets,
    int? repMin,
    int? repMax,
    double? targetWeight,
    bool clearTarget = false,
    int? restSeconds,
    bool? active,
    String? notes,
  }) {
    if (sets != null) item.sets = sets.clamp(1, 20);
    if (repMin != null) item.repMin = repMin.clamp(1, 600);
    if (repMax != null) item.repMax = repMax.clamp(1, 600);
    if (item.repMax < item.repMin) item.repMax = item.repMin;
    if (clearTarget) {
      item.targetWeight = null;
    } else if (targetWeight != null) {
      item.targetWeight = targetWeight;
    }
    if (restSeconds != null) item.restSeconds = restSeconds.clamp(0, 900);
    if (active != null) item.active = active;
    if (notes != null) item.notes = notes;
    _touch();
  }

  void deletePlanItem(PlanDay day, String itemId) {
    day.items.removeWhere((i) => i.id == itemId);
    _touch();
  }

  void reorderPlanItems(PlanDay day, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    day.items.insert(newIndex, day.items.removeAt(oldIndex));
    _touch();
  }

  /// Routines scheduled for today. Two means a choice day.
  List<PlanDay> get todaysDays => plan.daysForWeekday(now.weekday);
}
