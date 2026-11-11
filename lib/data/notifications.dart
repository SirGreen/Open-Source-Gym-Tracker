import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The plugin is a singleton behind a factory constructor, so the timezone
/// database and the Android initialisation only ever want doing once however
/// many notifiers are built on top of it.
bool _coreReady = false;
Future<void>? _coreInit;

Future<bool> _ensureCore() async {
  if (_coreReady) return true;
  _coreInit ??= _initCore();
  await _coreInit;
  return _coreReady;
}

Future<void> _initCore() async {
  try {
    tzdata.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));

    await FlutterLocalNotificationsPlugin().initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _coreReady = true;
  } catch (e) {
    // A phone that will not schedule notifications still logs workouts.
    debugPrint('Notifications unavailable: $e');
  }
}

/// Asks for notification permission once per app run, whichever notifier gets
/// there first. [exactAlarms] is for the rest timer, where a minute late is a
/// minute of rest you did not ask for; reminders do not need that precision
/// and so do not need the extra permission that goes with it.
bool _askedNotifications = false;
bool _askedExactAlarms = false;

Future<void> _ensurePermissions({bool exactAlarms = false}) async {
  if (!await _ensureCore()) return;
  try {
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (!_askedNotifications) {
      _askedNotifications = true;
      await android?.requestNotificationsPermission();
    }
    if (exactAlarms && !_askedExactAlarms) {
      _askedExactAlarms = true;
      await android?.requestExactAlarmsPermission();
    }
  } catch (e) {
    debugPrint('Notification permission request failed: $e');
  }
}

/// Fires the end-of-rest alert through the system, so it lands even with the
/// phone locked in a pocket. The in-app bar and vibration still work on their
/// own; this is purely the belt-and-braces part.
class RestNotifier {
  static const _channelId = 'rest_timer';
  static const _notificationId = 1001;
  static const _title = 'Rest over';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Rest timer',
      channelDescription: 'Fires when a rest period between sets ends',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      playSound: true,
      enableVibration: true,
      // The scheduled alert and the one posted at the end can both land. The
      // second replaces the first rather than sounding a second time.
      onlyAlertOnce: true,
    ),
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  bool get ready => _ready;

  Future<void> init() async {
    _ready = await _ensureCore();
  }

  /// Asked the first time a rest timer actually starts, rather than ambushing
  /// you on first launch.
  Future<void> ensurePermissions() => _ensurePermissions(exactAlarms: true);

  Future<void> scheduleAt(DateTime when, {required String body}) async {
    if (!_ready) return;
    await cancel();
    if (!when.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _notificationId,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        title: _title,
        body: body,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        notificationDetails: _details,
      );
    } catch (e) {
      debugPrint('Could not schedule rest alert: $e');
    }
  }

  /// Posts the alert straight away, for a rest that ends with the app still
  /// running but out of sight. The scheduled one cannot be relied on there:
  /// it needs the exact-alarm permission, which can be refused.
  Future<void> showNow({required String body}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _notificationId,
        title: _title,
        body: body,
        notificationDetails: _details,
      );
    } catch (e) {
      debugPrint('Could not show rest alert: $e');
    }
  }

  Future<void> cancel() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (e) {
      debugPrint('Could not cancel rest alert: $e');
    }
  }
}

/// One scheduled training day, reduced to what a reminder needs to say.
typedef ReminderDay = ({DateTime date, String title});

/// Nudges on the days the plan asks for, at a time of your choosing.
///
/// These are one-shot alerts booked a fortnight ahead rather than a weekly
/// repeat, because a repeat cannot know you already trained this morning.
/// Rebooking the whole run whenever anything changes keeps them honest: train
/// today and today's reminder is gone by the next sync.
class TrainingReminders {
  static const _channelId = 'training_days';

  /// Ids sit well clear of the rest timer's 1001.
  static const _baseId = 2000;
  static const horizon = 14;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// What the last sync booked. Rescheduling is not free and this is called on
  /// every state change, so an unchanged plan costs one string comparison.
  String _booked = '';

  @visibleForTesting
  String get booked => _booked;

  Future<void> sync({
    required bool enabled,
    required int hour,
    required int minute,
    required List<ReminderDay> days,
  }) async {
    final wanted = enabled
        ? [
            '$hour:$minute',
            for (final d in days.take(horizon))
              '${d.date.toIso8601String()}~${d.title}',
          ].join('|')
        : '';
    if (wanted == _booked) return;

    if (!await _ensureCore()) return;
    await cancelAll();
    _booked = wanted;
    if (!enabled) return;

    await _ensurePermissions();

    final now = DateTime.now();
    var id = _baseId;
    for (final day in days.take(horizon)) {
      final when = DateTime(
        day.date.year,
        day.date.month,
        day.date.day,
        hour,
        minute,
      );
      // Today's slot has usually already gone by when the app is opened in the
      // evening; a reminder in the past is not worth an alarm.
      if (!when.isAfter(now)) continue;
      await _schedule(id++, when, day.title);
    }
  }

  Future<void> _schedule(int id, DateTime when, String title) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        title: title,
        body: 'Scheduled today. Nothing logged yet.',
        // Inexact on purpose: a training reminder does not need to be to the
        // second, and exact alarms cost a permission prompt that does.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Training days',
            channelDescription: 'A nudge on days the plan schedules a workout',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Could not schedule training reminder: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_coreReady) return;
    for (var id = _baseId; id < _baseId + horizon; id++) {
      try {
        await _plugin.cancel(id: id);
      } catch (e) {
        debugPrint('Could not cancel training reminder: $e');
      }
    }
  }
}
