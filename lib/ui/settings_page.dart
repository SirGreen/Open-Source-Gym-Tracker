import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_state.dart';
import '../data/live_timer.dart';
import '../models/models.dart';
import '../utils/formatting.dart' as fmt;
import 'bodyweight_page.dart';
import 'exercise_library_page.dart';

/// Writes a backup and hands it to the share sheet. Top-level because the
/// overdue-backup card on Today offers the very same action, and a backup you
/// have to go hunting through Settings for is one you do not take.
Future<void> exportBackup(BuildContext context, AppState state) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final path = await state.exportToFile();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'Chalk backup',
        text: 'Chalk backup',
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _Label('BODYWEIGHT'),
          ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: Text(
              '${fmt.trimNum(double.parse(state.currentBodyweight.toStringAsFixed(1)))} kg',
            ),
            subtitle: Text(
              state.bodyweights.isEmpty
                  ? 'No weigh-ins logged yet — tap to add one'
                  : '7-day average of ${state.bodyweights.length} weigh-ins. '
                        'Drives net pull on the assist machine, bodyweight volume '
                        'and the pull-up goal marker.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openBodyweightPage(context),
          ),
          const Divider(height: 32),
          const _Label('REST TIMER'),
          SwitchListTile(
            title: const Text('Start automatically'),
            subtitle: const Text('Begins counting when you tick off a set'),
            value: s.autoRest,
            onChanged: (v) => state.updateSettings(autoRest: v),
          ),
          SwitchListTile(
            title: const Text('Vibrate when rest ends'),
            value: s.vibrate,
            onChanged: (v) => state.updateSettings(vibrate: v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Rest length comes from each exercise\'s type: heavy compounds '
              '2:30, moderate compounds 1:30, isolation 1:00, core 0:40. '
              'Override any of them per exercise in the plan.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          const _LiveTimerTile(),
          const Divider(height: 32),
          const _Label('TRAINING REMINDERS'),
          SwitchListTile(
            title: const Text('Remind me on scheduled days'),
            subtitle: const Text(
              'Only on days the plan asks for, and only while nothing is '
              'logged yet',
            ),
            value: s.remindTraining,
            onChanged: (v) => state.updateSettings(remindTraining: v),
          ),
          ListTile(
            enabled: s.remindTraining,
            leading: const Icon(Icons.schedule),
            title: const Text('Time of day'),
            subtitle: Text(_clockLabel(s.remindHour, s.remindMinute)),
            trailing: const Icon(Icons.chevron_right),
            onTap: s.remindTraining ? () => _pickTime(context, state) : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Booked a fortnight ahead and rebuilt whenever the plan or the '
              'log changes, so training in the morning cancels the evening '
              'nudge. Rest days and days you have written off are skipped.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 32),
          const _Label('AUTOMATIC PROGRESSION'),
          SwitchListTile(
            title: const Text('Step the load up for me'),
            subtitle: const Text(
              'Next session opens at the new weight with reps back at the '
              'bottom of the range',
            ),
            value: s.autoProgress,
            onChanged: (v) => state.updateSettings(autoProgress: v),
          ),
          ListTile(
            enabled: s.autoProgress,
            title: const Text('Sessions needed first'),
            subtitle: Text(
              s.autoProgressSessions == 1
                  ? 'One qualifying session'
                  : '${s.autoProgressSessions} qualifying sessions in a row',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: s.autoProgress ? () => _pickStreak(context, state) : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'A session qualifies when every set reaches the top of the rep '
              'range and the last set is RPE 8 or easier. Changing the weight, '
              'missing a rep or leaving the RPE blank restarts the count. Only '
              "applies where the machine's increment is known — everything "
              'else still just asks.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          const Divider(height: 32),
          const _Label('GYM QUIRKS'),
          SwitchListTile(
            title: const Text('Show pounds alongside kg'),
            subtitle: const Text('Cable stacks here are labelled in lb'),
            value: s.showLbHint,
            onChanged: (v) => state.updateSettings(showLbHint: v),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Plates available per side, for the plate calculator.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in ([...s.plates]..sort((a, b) => b.compareTo(a))))
                  InputChip(
                    label: Text('${fmt.trimNum(p)} kg'),
                    onDeleted: () =>
                        state.updateSettings(plates: [...s.plates]..remove(p)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  onPressed: () => _addPlate(context, state),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          const _Label('APPEARANCE'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<AppTheme>(
              segments: [
                for (final t in AppTheme.values)
                  ButtonSegment(value: t, label: Text(t.label)),
              ],
              selected: {s.theme},
              showSelectedIcon: false,
              onSelectionChanged: (v) => state.updateSettings(theme: v.first),
            ),
          ),
          const Divider(height: 32),
          const _Label('LIBRARY'),
          ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Exercises'),
            subtitle: Text('${state.exercises.length} movements'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExerciseLibraryPage()),
            ),
          ),
          const Divider(height: 32),
          const _Label('BACKUP'),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Export backup'),
            subtitle: const Text('Share a JSON file with everything in it'),
            onTap: () => exportBackup(context, state),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Import backup'),
            subtitle: const Text('Replaces all current data'),
            onTap: () => _import(context, state),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Export the log as CSV'),
            subtitle: const Text('One row per set, for a spreadsheet'),
            onTap: () => _exportCsv(context, state),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore a snapshot'),
            subtitle: const Text(
              'Automatic copies kept on this phone after every workout',
            ),
            onTap: () => _restoreSnapshot(context, state),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  state.exportOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  size: 16,
                  color: state.exportOverdue ? scheme.error : scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    switch (state.daysSinceExport) {
                      null =>
                        'Nothing has ever left this phone. Snapshots live '
                            'here too, so they go with it — export one somewhere '
                            'else.',
                      0 => 'Exported off this phone today.',
                      1 => 'Last exported off this phone yesterday.',
                      final days =>
                        'Last exported off this phone $days days '
                            'ago.',
                    },
                    style: TextStyle(
                      fontSize: 12,
                      color: state.exportOverdue
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          const _Label('DANGER ZONE'),
          ListTile(
            leading: Icon(Icons.delete_sweep_outlined, color: scheme.error),
            title: Text(
              'Clear workout history',
              style: TextStyle(color: scheme.error),
            ),
            subtitle: const Text('Keeps your plan, goals and exercises'),
            onTap: () => _confirm(
              context,
              title: 'Clear history?',
              message:
                  'Every logged workout is deleted. Your plan stays as it is.',
              onOk: state.clearHistory,
              okLabel: 'Clear',
            ),
          ),
          ListTile(
            leading: Icon(Icons.restart_alt, color: scheme.error),
            title: Text(
              'Reset everything',
              style: TextStyle(color: scheme.error),
            ),
            subtitle: const Text('Back to the plan as written in the document'),
            onTap: () => _confirm(
              context,
              title: 'Reset the app?',
              message:
                  'History, plan, goals and custom exercises are wiped and '
                  'replaced with the seeded training plan.',
              onOk: state.resetToSeed,
              okLabel: 'Reset',
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Chalk · data stays on this device',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStreak(BuildContext context, AppState state) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final n in const [1, 2, 3])
              ListTile(
                title: Text(
                  n == 1
                      ? 'One qualifying session'
                      : '$n qualifying sessions in a row',
                ),
                subtitle: Text(
                  n == 1
                      ? 'Matches the rule as written in the plan'
                      : 'Slower, and more certain the weight is really easy',
                ),
                onTap: () => Navigator.of(context).pop(n),
              ),
          ],
        ),
      ),
    );
    if (value != null) state.updateSettings(autoProgressSessions: value);
  }

  Future<void> _restoreSnapshot(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final snapshots = await state.autoBackups();
    if (!context.mounted) return;

    if (snapshots.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'No snapshots yet — one is written after each workout.',
          ),
        ),
      );
      return;
    }

    final chosen = await showModalBottomSheet<File>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Restoring replaces everything with that snapshot.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            for (final file in snapshots)
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(_snapshotLabel(file)),
                onTap: () => Navigator.of(context).pop(file),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;

    try {
      await state.restoreAutoBackup(chosen);
      messenger.showSnackBar(
        const SnackBar(content: Text('Snapshot restored')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  /// "auto-2026-09-04T22-10-31.json" -> "4 Sep 2026, 22:10"
  static String _snapshotLabel(File file) {
    final name = file.uri.pathSegments.last;
    final stamp = name
        .replaceFirst('auto-', '')
        .replaceFirst('.json', '')
        .replaceFirstMapped(
          RegExp(r'T(\d\d)-(\d\d)-(\d\d)'),
          (m) => 'T${m[1]}:${m[2]}:${m[3]}',
        );
    final parsed = DateTime.tryParse(stamp);
    return parsed == null
        ? name
        : '${fmt.dayMonth(parsed)} ${parsed.year}, ${fmt.timeOfDay(parsed)}';
  }

  Future<void> _addPlate(BuildContext context, AppState state) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add plate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(double.tryParse(controller.text.replaceAll(',', '.'))),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (value == null || value <= 0) return;
    if (state.settings.plates.contains(value)) return;
    state.updateSettings(plates: [...state.settings.plates, value]);
  }

  Future<void> _exportCsv(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await state.exportCsvToFile();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: 'Chalk training log',
          text: 'Chalk training log',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _pickTime(BuildContext context, AppState state) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: state.settings.remindHour,
        minute: state.settings.remindMinute,
      ),
    );
    if (picked == null) return;
    state.updateSettings(remindHour: picked.hour, remindMinute: picked.minute);
  }

  static String _clockLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Future<void> _import(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
          'Everything currently in the app is replaced by the contents of the '
          'file you pick.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final file = await FilePicker.pickFile(dialogTitle: 'Pick a backup file');
      if (file == null) return;

      final content = utf8.decode(await file.readAsBytes());
      final decoded = jsonDecode(content);
      if (decoded is! Map) throw const FormatException('Not a JSON object');
      state.importFrom(Map<String, dynamic>.from(decoded));
      messenger.showSnackBar(const SnackBar(content: Text('Backup restored')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onOk,
    required String okLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(okLabel),
          ),
        ],
      ),
    );
    if (ok == true) onOk();
  }
}

/// Whether the countdown reaches the status bar and the lock screen.
///
/// Four things have to line up and three of them are the phone's call, so a
/// missing chip is worth explaining rather than leaving as a mystery. Tapping
/// re-checks; where there is a switch to throw, it goes there.
class _LiveTimerTile extends StatefulWidget {
  const _LiveTimerTile();

  @override
  State<_LiveTimerTile> createState() => _LiveTimerTileState();
}

class _LiveTimerTileState extends State<_LiveTimerTile> {
  LiveTimerStatus? _status;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final status = await liveTimer.status();
    if (mounted) setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _status;

    if (status == null) {
      return const ListTile(
        leading: Icon(Icons.hourglass_top_outlined),
        title: Text('Countdown on the lock screen'),
        subtitle: Text('Checking…'),
      );
    }

    // Ordered by which gate is shut first, because the first one is the one
    // worth doing something about.
    final (String detail, bool fixable) = switch (status) {
      _ when !status.supported => (
        'Needs Android 16 or later. On an older phone the countdown still '
            'sits in the notification shade, just not as a chip.',
        false,
      ),
      _ when !status.notificationsOn => (
        'Notifications are off for Chalk, so there is nothing to promote. '
            'Tap to turn them on.',
        true,
      ),
      _ when !status.allowed => (
        'Live notifications are switched off for Chalk. Tap to allow them.',
        true,
      ),
      _ when status.running && !status.qualifies => (
        'A timer is running but its notification does not qualify for '
            'promotion. That one is a bug in Chalk, not a setting.',
        false,
      ),
      _ when status.running && !status.promoted => (
        'A timer is running and qualifies, but the phone has not promoted '
            'it. On Samsung, look for "Live notifications for all apps" in '
            'Developer options.',
        false,
      ),
      _ when status.running => (
        'Showing now, on the status bar and the Now Bar.',
        false,
      ),
      _ => ('Ready. It appears when a rest or a hold starts.', false),
    };

    return ListTile(
      leading: Icon(
        status.ready ? Icons.check_circle_outline : Icons.error_outline,
        color: status.ready
            ? scheme.primary
            : status.supported
            ? scheme.error
            : scheme.onSurfaceVariant,
      ),
      title: const Text('Countdown on the lock screen'),
      subtitle: Text(detail),
      trailing: fixable ? const Icon(Icons.chevron_right) : null,
      onTap: fixable
          ? () async {
              await liveTimer.openSystemSettings();
              await _check();
            }
          : _check,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
