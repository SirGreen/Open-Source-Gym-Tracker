import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'data/notifications.dart';
import 'data/rest_timer.dart';
import 'models/models.dart';
import 'theme.dart';
import 'ui/home_shell.dart';
import 'ui/newer_data_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const GymTrackerApp());
}

class GymTrackerApp extends StatefulWidget {
  const GymTrackerApp({super.key});

  @override
  State<GymTrackerApp> createState() => _GymTrackerAppState();
}

class _GymTrackerAppState extends State<GymTrackerApp> {
  final AppState _state = AppState();
  final RestNotifier _notifier = RestNotifier();
  final TrainingReminders _reminders = TrainingReminders();
  late final RestTimer _rest = RestTimer(notifier: _notifier);
  AppLifecycleListener? _lifecycle;
  Timer? _remindersDebounce;

  @override
  void initState() {
    super.initState();
    _state.load();
    _notifier.init();
    // Rebooked whenever anything changes, so finishing a workout or moving a
    // routine to another weekday is reflected without the user doing anything.
    _state.addListener(_queueReminderSync);
    _lifecycle = AppLifecycleListener(
      // Write pending changes as soon as the app leaves the foreground.
      onInactive: _state.flush,
      // A rest that ends out of sight should still say so.
      onStateChange: (s) => _rest.inFront = s == AppLifecycleState.resumed,
    );
  }

  @override
  void dispose() {
    _remindersDebounce?.cancel();
    _state.removeListener(_queueReminderSync);
    _lifecycle?.dispose();
    _rest.dispose();
    _state.dispose();
    super.dispose();
  }

  /// Coalesced: logging a set notifies on every keystroke, and rebuilding a
  /// fortnight of reminders is not something to do between digits.
  void _queueReminderSync() {
    _remindersDebounce?.cancel();
    _remindersDebounce = Timer(const Duration(seconds: 3), _syncReminders);
  }

  void _syncReminders() {
    // Nothing is read while a newer document is held back, so there is no plan
    // to remind anyone about and no business cancelling what is already booked.
    if (!_state.ready || _state.blockedByNewerData) return;
    unawaited(
      _reminders.sync(
        enabled: _state.settings.remindTraining,
        hour: _state.settings.remindHour,
        minute: _state.settings.remindMinute,
        days: [
          for (final day in _state.upcomingTrainingDays())
            (date: day.date, title: day.title),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _state),
        ChangeNotifierProvider.value(value: _rest),
      ],
      // Inside the providers, so the palette can follow the setting.
      child: Builder(
        builder: (context) {
          final theme = context.select<AppState, AppTheme>(
            (s) => s.settings.theme,
          );
          return MaterialApp(
            title: 'Chalk',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: switch (theme) {
              AppTheme.system => ThemeMode.system,
              AppTheme.light => ThemeMode.light,
              AppTheme.dark => ThemeMode.dark,
            },
            home: const _Root(),
          );
        },
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final ready = context.select<AppState, bool>((s) => s.ready);
    if (!ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Held before the app proper: starting it is what would cost you the
    // parts of the log this build cannot read.
    final blocked = context.select<AppState, bool>((s) => s.blockedByNewerData);
    if (blocked) return const NewerDataPage();
    return const HomeShell();
  }
}
