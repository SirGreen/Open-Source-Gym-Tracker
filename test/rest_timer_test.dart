import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/live_timer.dart';
import 'package:gym_tracker/data/notifications.dart';
import 'package:gym_tracker/data/rest_timer.dart';

/// Records what the timer asked of the system instead of asking it.
class _FakeNotifier extends RestNotifier {
  final calls = <String>[];

  @override
  Future<void> ensurePermissions() async {}

  @override
  Future<void> scheduleAt(DateTime when, {required String body}) async =>
      calls.add('schedule: $body');

  @override
  Future<void> showNow({required String body}) async =>
      calls.add('show: $body');

  @override
  Future<void> cancel() async => calls.add('cancel');
}

void main() {
  // The live chip talks over a channel, which needs the test binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rest alert', () {
    const channel = MethodChannel('test/live_timer');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
    });

    ({RestTimer rest, _FakeNotifier notifier}) timer() {
      final notifier = _FakeNotifier();
      final rest = RestTimer(
        notifier: notifier,
        live: LiveTimer(channel: channel),
      )..vibrateEnabled = false;
      return (rest: rest, notifier: notifier);
    }

    /// The countdown reads the real clock, so a rest has to really elapse.
    Future<void> sitOut(RestTimer rest) async {
      rest.start(1);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      expect(rest.running, isFalse);
    }

    test('a rest that ends out of sight leaves a notification', () async {
      final t = timer();
      t.rest
        ..label = 'Lat pulldown'
        ..inFront = false;

      await sitOut(t.rest);

      expect(t.notifier.calls, [
        'schedule: Lat pulldown — next set is up.',
        'show: Lat pulldown — next set is up.',
      ]);
    });

    test('with the app on screen the flash is enough', () async {
      final t = timer();

      await sitOut(t.rest);

      expect(t.notifier.calls, ['schedule: Next set is up.', 'cancel']);
    });

    test('coming back clears the alert, but never a pending one', () {
      final t = timer();
      t.rest
        ..inFront = false
        ..start(60)
        ..inFront = true;
      expect(
        t.notifier.calls,
        isNot(contains('cancel')),
        reason: 'the rest is still running and its alert still due',
      );

      t.rest.stop();
      t.notifier.calls.clear();
      t.rest
        ..inFront = false
        ..inFront = true;
      expect(t.notifier.calls, ['cancel']);
    });
  });
}
