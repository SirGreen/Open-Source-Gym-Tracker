import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Everything lives in one JSON document in the app's private documents dir.
/// Writes go to a temp file first so a crash mid-save can never leave a
/// half-written database behind.
class Storage {
  static const fileName = 'gym_tracker_data.json';

  /// The format this build writes and is prepared to read.
  ///
  /// Raise it only for a change an older build would get *wrong* — a field
  /// restructured, or one whose meaning shifted under the same name. Adding
  /// optional fields does not count: an older build ignores what it does not
  /// know, and the cost of that is a lost preference, not a lost log.
  ///
  /// Raising it is not free. A document written at a higher number stops the
  /// older build dead rather than letting it quietly re-save a document it
  /// half understood, which is the whole point — but it does mean the older
  /// build cannot be used at all until it is updated.
  static const schemaVersion = 1;

  Future<File> file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  Future<Map<String, dynamic>?> load() async {
    try {
      final f = await file();
      if (!await f.exists()) return null;
      final text = await f.readAsString();
      if (text.trim().isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Corrupt or unreadable file: fall back to a fresh seed rather than
      // trapping the user on a crash loop.
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    final f = await file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    // Straight over the top: rename replaces the destination in one step, so
    // there is never a moment with no database on disk. Deleting the old file
    // first would open exactly the window this temp-file dance exists to close.
    await tmp.rename(f.path);
  }

  Future<Directory> _backupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backups = Directory('${dir.path}${Platform.pathSeparator}backups');
    if (!await backups.exists()) await backups.create(recursive: true);
    return backups;
  }

  /// Snapshot taken after every finished workout, keeping the newest [keep].
  /// This is on-device: it rescues a bad import or a corrupt save, but it goes
  /// with the phone, so it does not replace exporting off-device.
  Future<File> writeAutoBackup(
    Map<String, dynamic> data, {
    int keep = 10,
  }) async {
    final dir = await _backupDir();
    final stamp = DateTime.now()
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(':', '-');
    final file = File('${dir.path}${Platform.pathSeparator}auto-$stamp.json');
    await file.writeAsString(jsonEncode(data), flush: true);

    for (final stale in (await listAutoBackups()).skip(keep)) {
      try {
        await stale.delete();
      } catch (_) {
        // A snapshot we cannot prune is not worth failing a workout over.
      }
    }
    return file;
  }

  /// Newest first — the timestamp in the name sorts lexicographically.
  Future<List<File>> listAutoBackups() async {
    final dir = await _backupDir();
    final files =
        (await dir.list().toList())
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Copies the live database out, byte for byte, for sharing.
  ///
  /// Deliberately not [writeExport]: that re-serialises through this build's
  /// own model, which is exactly what must not happen to a document written by
  /// a newer version. The point is to rescue the file intact.
  Future<File> copyForExport(String name) async {
    final dir = await getTemporaryDirectory();
    final target = File('${dir.path}${Platform.pathSeparator}$name');
    return (await file()).copy(target.path);
  }

  /// Writes plain text for sharing — the CSV log — and returns it.
  Future<File> writeTextExport(String text, String name) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}$name');
    await f.writeAsString(text, flush: true);
    return f;
  }

  /// Writes a copy for sharing and returns it.
  Future<File> writeExport(Map<String, dynamic> data, String name) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}$name');
    await f.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    return f;
  }
}
