import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import 'live_timer.dart';
import 'notifications.dart';

/// Countdown between sets. Deadline-based rather than tick-counting, so it
/// stays accurate if the isolate is throttled while the screen is off.
class RestTimer extends ChangeNotifier {
  RestTimer({RestNotifier? notifier, LiveTimer? live})
    : _notifier = notifier,
      _live = live ?? liveTimer;

  /// Null in tests and on platforms without notifications.
  final RestNotifier? _notifier;

  /// Mirrors the countdown onto the status bar and lock screen.
  final LiveTimer _live;

  /// What the chip should call this rest, set by whoever starts it.
  String label = 'Rest';

  Timer? _ticker;
  DateTime? _endsAt;
  int _total = 0;
  bool _justFinished = false;

  bool vibrateEnabled = true;

  /// Whether the app is on screen, kept current by the app's lifecycle
  /// listener. A rest that ends out of sight leaves a notification behind.
  bool get inFront => _inFront;
  bool _inFront = true;
  set inFront(bool value) {
    if (value == _inFront) return;
    _inFront = value;
    // Back in the app after the alert went off: it has done its job. While a
    // rest is still running the pending alert is left alone.
    if (value && !running) unawaited(_notifier?.cancel());
  }

  bool get running => _endsAt != null;
  int get total => _total;

  /// Seconds left, never negative.
  int get remaining {
    final end = _endsAt;
    if (end == null) return 0;
    final left = end.difference(DateTime.now()).inMilliseconds / 1000;
    return left <= 0 ? 0 : left.ceil();
  }

  double get progress {
    if (_total <= 0 || !running) return 0;
    return (1 - remaining / _total).clamp(0.0, 1.0);
  }

  /// True for one frame after the countdown reaches zero, so the UI can flash.
  bool get justFinished => _justFinished;

  void start(int seconds) {
    if (seconds <= 0) return;
    _total = seconds;
    final end = DateTime.now().add(Duration(seconds: seconds));
    _endsAt = end;
    _justFinished = false;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    notifyListeners();
    _tick();
    _arm(end);
  }

  /// The Dart timer only fires while the app is alive; the scheduled alert is
  /// what reaches you with the screen off.
  Future<void> _arm(DateTime end) async {
    final notifier = _notifier;
    if (notifier == null) return;
    await notifier.ensurePermissions();
    await notifier.scheduleAt(end, body: _alertBody);
  }

  /// Names the exercise when there is one, so a glance at the lock screen says
  /// what is next.
  String get _alertBody =>
      label == 'Rest' ? 'Next set is up.' : '$label — next set is up.';

  void addSeconds(int delta) {
    final end = _endsAt;
    if (end == null) return;
    final next = end.add(Duration(seconds: delta));
    if (next.isBefore(DateTime.now())) {
      stop();
      return;
    }
    _endsAt = next;
    _total = (_total + delta).clamp(1, 3600);
    notifyListeners();
    unawaited(_arm(next));
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _endsAt = null;
    _total = 0;
    _justFinished = false;
    notifyListeners();
    unawaited(_notifier?.cancel());
    unawaited(_live.hide());
  }

  void _tick() {
    if (!running) return;
    if (remaining > 0) {
      final end = _endsAt;
      if (end != null) {
        unawaited(
          _live.countdown(
            title: label,
            text: 'Rest between sets',
            endsAt: end,
            total: _total,
            remaining: remaining,
          ),
        );
      }
    }
    if (remaining <= 0) {
      _ticker?.cancel();
      _ticker = null;
      _endsAt = null;
      _justFinished = true;
      notifyListeners();
      unawaited(_live.hide());
      _buzz();
      if (_inFront) {
        // You are looking at the flash, so the system alert would only
        // repeat it.
        unawaited(_notifier?.cancel());
      } else {
        // Locked, or in another app. The process is kept alive for the
        // countdown chip, so this tick runs — and it is the moment the chip
        // vanishes, so leave word that the rest is over in its place.
        unawaited(_notifier?.showNow(body: _alertBody));
      }
      // Clear the flash flag shortly after.
      Timer(const Duration(seconds: 3), () {
        if (_justFinished) {
          _justFinished = false;
          notifyListeners();
        }
      });
      return;
    }
    notifyListeners();
  }

  Future<void> _buzz() async {
    if (!vibrateEnabled) return;
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(pattern: [0, 350, 180, 350, 180, 550]);
      }
    } catch (e) {
      debugPrint('Vibration unavailable: $e');
    }
  }

  /// One firm buzz: a hold has reached its target. Long enough to feel with
  /// the phone on the floor, short enough not to be mistaken for the
  /// end-of-rest alarm.
  Future<void> buzzTarget() async {
    if (!vibrateEnabled) return;
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 320, amplitude: 160);
      }
    } catch (_) {
      // Haptics are a nicety; never let them break set logging.
    }
  }

  Future<void> buzzShort() async {
    if (!vibrateEnabled) return;
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 40, amplitude: 90);
      }
    } catch (_) {
      // Haptics are a nicety; never let them break set logging.
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_notifier?.cancel());
    super.dispose();
  }
}
