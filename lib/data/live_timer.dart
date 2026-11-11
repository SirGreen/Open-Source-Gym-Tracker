import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Mirrors whatever timer is running onto the system: the Android 16
/// status-bar chip, and Samsung's Now Bar on the lock screen.
///
/// Everything here is best-effort. The platform side can be missing (tests,
/// other platforms) or refused (notifications turned off), and none of that is
/// a reason for a set to go unlogged — so every call swallows its failure.
class LiveTimer {
  LiveTimer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('chalk/live_timer');

  final MethodChannel _channel;

  /// Off by default; the settings switch turns it on.
  bool enabled = true;

  /// The last second pushed, so a 4 Hz ticker does not post 4 Hz of updates.
  int? _lastSecond;
  String? _lastKind;

  /// Counting down to the end of a rest.
  Future<void> countdown({
    required String title,
    required String text,
    required DateTime endsAt,
    required int total,
    required int remaining,
  }) => _show(
    kind: 'rest',
    title: title,
    text: text,
    shortText: _short(remaining),
    countdown: true,
    when: endsAt,
    progress: total - remaining,
    progressMax: total,
    second: remaining,
  );

  /// Counting up through a hold. [target] may be zero when the movement has no
  /// planned time, in which case the bar runs indeterminate.
  Future<void> countUp({
    required String title,
    required String text,
    required DateTime startedAt,
    required int elapsed,
    required int target,
  }) => _show(
    kind: 'hold',
    title: title,
    text: text,
    shortText: _short(elapsed),
    countdown: false,
    when: startedAt,
    progress: elapsed,
    progressMax: target,
    second: elapsed,
  );

  Future<void> _show({
    required String kind,
    required String title,
    required String text,
    required String shortText,
    required bool countdown,
    required DateTime when,
    required int progress,
    required int progressMax,
    required int second,
  }) async {
    if (!enabled) return;
    if (kind == _lastKind && second == _lastSecond) return;
    _lastKind = kind;
    _lastSecond = second;

    try {
      await _channel.invokeMethod<void>('show', {
        'title': title,
        'text': text,
        'shortText': shortText,
        'countdown': countdown,
        'whenMillis': when.millisecondsSinceEpoch,
        'progress': progress,
        'progressMax': progressMax,
        'color': 0xFF00C853,
      });
    } catch (e) {
      debugPrint('Live timer unavailable: $e');
    }
  }

  /// What the platform makes of the chip right now. Everything reads false on
  /// a phone or a test where the channel is not there, which is the same thing
  /// the user sees: no chip.
  Future<LiveTimerStatus> status() async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('status');
      if (map == null) return const LiveTimerStatus();
      return LiveTimerStatus(
        supported: map['supported'] == true,
        notificationsOn: map['notifications'] == true,
        allowed: map['allowed'] == true,
        running: map['running'] == true,
        qualifies: map['qualifies'] == true,
        promoted: map['promoted'] == true,
      );
    } catch (e) {
      debugPrint('Live timer unavailable: $e');
      return const LiveTimerStatus();
    }
  }

  /// Opens the system screen that owns the switch, when the phone is the one
  /// saying no.
  Future<void> openSystemSettings() async {
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (e) {
      debugPrint('Live timer unavailable: $e');
    }
  }

  Future<void> hide() async {
    _lastSecond = null;
    _lastKind = null;
    try {
      await _channel.invokeMethod<void>('hide');
    } catch (e) {
      debugPrint('Live timer unavailable: $e');
    }
  }

  /// Chip text: seconds while short, m:ss once it is worth grouping.
  static String _short(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    final s = seconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// One per app. The rest timer and the hold timer both drive it, and only one
/// of them can be running at a time.
final liveTimer = LiveTimer();

/// Why the countdown is, or is not, on the status bar and the Now Bar.
///
/// Four things have to be true and only the last is ours: the phone has to be
/// new enough, notifications have to be on, the app has to be allowed to
/// promote them, and the notification has to qualify. Kept apart rather than
/// reduced to one boolean because the fix is different in each case.
class LiveTimerStatus {
  const LiveTimerStatus({
    this.supported = false,
    this.notificationsOn = false,
    this.allowed = false,
    this.running = false,
    this.qualifies = false,
    this.promoted = false,
  });

  /// Android 16 or later. Below that there is no chip to appear on.
  final bool supported;

  final bool notificationsOn;

  /// Live Updates are not switched off for this app.
  final bool allowed;

  /// A timer's notification is posted right now. The two flags below only
  /// mean anything while it is.
  final bool running;

  /// The notification meets the platform's rules for promotion.
  final bool qualifies;

  /// The platform actually promoted it — the chip is up.
  final bool promoted;

  /// Nothing more to do: either it is promoted, or it will be as soon as a
  /// timer starts.
  bool get ready =>
      supported && notificationsOn && allowed && (!running || promoted);
}
