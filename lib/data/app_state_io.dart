part of 'app_state.dart';

/// Settings, and everything that moves data in or out of the app.
///
/// The backup rules live here too: what counts as a backup, what merely
/// leaves the phone, and what refuses to be read at all.
extension SettingsAndBackup on AppState {
  void updateSettings({
    double? bodyweightKg,
    bool? vibrate,
    bool? autoRest,
    List<double>? plates,
    bool? showLbHint,
    bool? autoProgress,
    int? autoProgressSessions,
    AppTheme? theme,
    bool? remindTraining,
    int? remindHour,
    int? remindMinute,
  }) {
    if (bodyweightKg != null && bodyweightKg > 0) {
      settings.bodyweightKg = bodyweightKg;
    }
    if (vibrate != null) settings.vibrate = vibrate;
    if (autoRest != null) settings.autoRest = autoRest;
    if (plates != null) settings.plates = plates;
    if (showLbHint != null) settings.showLbHint = showLbHint;
    if (autoProgress != null) settings.autoProgress = autoProgress;
    if (autoProgressSessions != null) {
      settings.autoProgressSessions = autoProgressSessions.clamp(1, 5);
    }
    if (theme != null) settings.theme = theme;
    if (remindTraining != null) settings.remindTraining = remindTraining;
    if (remindHour != null) settings.remindHour = remindHour.clamp(0, 23);
    if (remindMinute != null) settings.remindMinute = remindMinute.clamp(0, 59);
    _touch();
  }

  /// Snapshot after every finished workout. Never allowed to fail a workout.
  Future<void> _autoBackup() async {
    try {
      await _storage.writeAutoBackup(toJson());
    } catch (e) {
      debugPrint('Auto-backup failed: $e');
    }
  }

  Future<List<Snapshot>> autoBackups() => _storage.listAutoBackups();

  Future<void> restoreAutoBackup(Snapshot snapshot) async {
    final decoded = jsonDecode(await snapshot.read());
    if (decoded is! Map) throw const FormatException('Unreadable snapshot');
    importFrom(Map<String, dynamic>.from(decoded));
  }

  /// Days since a backup last left the device, or null if it never has.
  int? get daysSinceExport {
    final last = settings.lastExportedAt;
    if (last == null) return null;
    return dateOnly(now).difference(dateOnly(last)).inDays;
  }

  /// The on-device snapshots go with the phone, so nagging is warranted.
  bool get exportOverdue => daysSinceExport == null || daysSinceExport! >= 14;

  Future<XFile> exportToFile() async {
    final stamp = now.toIso8601String().split('T').first;
    final f = await _storage.writeExport(toJson(), 'chalk-backup-$stamp.json');
    settings.lastExportedAt = now;
    _touch();
    return f;
  }

  /// The log as one row per completed set, for a spreadsheet.
  ///
  /// This is a way *out* of the app, not a way back in: it flattens the log
  /// and drops the plan, goals and exercise library entirely, so it is not a
  /// backup and deliberately does not count as one.
  String toCsv() {
    final rows = <String>[
      'date,time,session,routine,exercise,muscle,equipment,set,warmup,'
          'weight_kg,reps,duration_s,tempo_s,rpe,effective_load_kg,e1rm_kg,'
          'volume_kg,bodyweight_kg,set_notes',
    ];

    // Oldest first: a spreadsheet reads down the page, unlike the history list.
    for (final session in finishedSessions.reversed) {
      final bw = bodyweightFor(session);
      final routine = plan.byId(session.planDayId)?.name ?? '';
      for (final performed in session.exercises) {
        final def = exerciseById(performed.exerciseId);
        var index = 0;
        for (final set in performed.sets) {
          if (!set.done) continue;
          index++;
          rows.add(
            [
              _csvDate(session.start),
              timeOfDay(session.start),
              session.title,
              routine,
              def.name,
              def.muscle.label,
              def.equipment.label,
              '$index',
              set.warmup ? 'yes' : 'no',
              trimNum(set.weight),
              '${set.reps}',
              set.durationSeconds?.toString() ?? '',
              set.tempoSeconds == null ? '' : trimNum(set.tempoSeconds!),
              set.rpe == null ? '' : trimNum(set.rpe!),
              trimNum(effectiveLoad(def, set, bw)),
              trimNum(estimated1rm(def, set, bw)),
              trimNum(setVolume(def, set, bw)),
              trimNum(bw),
              set.notes,
            ].map(_csvCell).join(','),
          );
        }
      }
    }
    return rows.join('\r\n');
  }

  Future<XFile> exportCsvToFile() {
    final stamp = _csvDate(now);
    // Not recorded as a backup: restoring from this is impossible, so letting
    // it silence the "nothing has left this phone" warning would be a lie.
    return _storage.writeTextExport(toCsv(), 'chalk-log-$stamp.csv');
  }

  static String _csvDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  /// Quotes only when it has to, and doubles any quote already inside.
  static String _csvCell(String value) {
    final clean = value.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (!clean.contains(RegExp(r'[",]'))) return clean;
    return '"${clean.replaceAll('"', '""')}"';
  }

  /// Replaces everything with the contents of a backup. Throws on bad input.
  void importFrom(Map<String, dynamic> data) {
    if (data['plan'] == null && data['sessions'] == null) {
      throw const FormatException('Not a Chalk backup');
    }
    // A backup written by a newer version carries fields this build knows
    // nothing about, and _apply would drop every one of them without a word.
    // Refusing is the only honest answer: the file is intact until it is
    // imported, so the fix is to update the app, not to salvage what is left.
    // A missing version means a backup from before the field existed, which
    // this build does understand.
    final schema = (data['schema'] as num?)?.toInt() ?? Storage.schemaVersion;
    if (schema > Storage.schemaVersion) {
      throw FormatException(
        'This backup is from a newer version of Chalk (format $schema, this '
        'build reads ${Storage.schemaVersion}). Update the app, then import it.',
      );
    }
    _apply(data);
    // A backup taken on an older version is missing whatever has shipped
    // since — restoring it should not cost you those movements.
    _addShippedExercises();
    _touch();
  }

  void resetToSeed() {
    _applySeed();
    _touch();
  }

  void clearHistory() {
    sessions.removeWhere((s) => !s.isActive);
    missedDays.clear();
    _touch();
  }
}
