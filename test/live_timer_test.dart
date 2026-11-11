import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_tracker/data/live_timer.dart';

void main() {
  // The channel mock needs the test binding. Nothing in this file is a widget
  // test, so nothing else would set it up.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the live timer', () {
    const channel = MethodChannel('chalk/live_timer');

    /// Stands in for the Android side, which reports the gates rather than a
    /// single yes or no.
    void platformSays({
      bool supported = true,
      bool notifications = true,
      bool allowed = true,
      bool running = false,
      bool qualifies = false,
      bool promoted = false,
    }) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method != 'status') return null;
            return <String, Object?>{
              'sdk': supported ? 36 : 34,
              'supported': supported,
              'notifications': notifications,
              'allowed': allowed,
              'running': running,
              'qualifies': qualifies,
              'promoted': promoted,
            };
          });
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('a promoted countdown is the finished state', () async {
      platformSays(running: true, qualifies: true, promoted: true);

      final status = await LiveTimer().status();
      expect(status.promoted, isTrue);
      expect(status.ready, isTrue);
    });

    test('nothing running yet is still ready', () async {
      // The chip only exists while a timer does, so an idle app that is
      // allowed to promote has nothing wrong with it.
      platformSays();

      expect((await LiveTimer().status()).ready, isTrue);
    });

    test('a timer the phone refused to promote is not ready', () async {
      platformSays(running: true, qualifies: true);

      final status = await LiveTimer().status();
      expect(
        status.qualifies,
        isTrue,
        reason: 'the notification is not the problem',
      );
      expect(status.ready, isFalse);
    });

    test('live notifications switched off is not ready', () async {
      platformSays(allowed: false);

      expect((await LiveTimer().status()).ready, isFalse);
    });

    test('an older phone is not ready and never will be', () async {
      platformSays(supported: false);

      expect((await LiveTimer().status()).ready, isFalse);
    });

    test('no platform at all reads as no chip', () async {
      // Other platforms, and every widget test in this file.
      final status = await LiveTimer().status();

      expect(status.supported, isFalse);
      expect(status.ready, isFalse);
    });
  });
}
