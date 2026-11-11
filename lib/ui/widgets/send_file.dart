import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Gets an export off the device: the share sheet on a phone, a download in
/// the browser.
///
/// A browser's share sheet takes only some file types, and a JSON backup is
/// not one of them. A download lands in a folder you can find again, which is
/// the whole point of a backup.
Future<void> sendFile(XFile file, {required String subject}) async {
  if (kIsWeb) {
    await file.saveTo(file.name);
    return;
  }
  await SharePlus.instance.share(
    ShareParams(files: [file], subject: subject, text: subject),
  );
}
