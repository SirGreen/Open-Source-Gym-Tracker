import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'storage.dart';

/// Stands in for `storage_platform.dart` in the browser build.
Storage platformStorage() => WebStorage();

/// The browser build's [Storage]: the same single JSON document, kept in
/// IndexedDB because a web page has no file system to write it to.
///
/// One transaction per write does the job the temp-file rename does on the
/// phone. IndexedDB commits a `put` whole or not at all, so there is never a
/// half-written document to come back to.
///
/// What it cannot do is outlive the browser. Clearing site data takes it, and
/// so does Safari after a week without a visit unless the page has been added
/// to the home screen. [writeAutoBackup] asks the browser to hold on to it,
/// but the export is still the copy that matters.
class WebStorage extends Storage {
  /// [database] is only ever changed by tests, so each gets a clean one.
  WebStorage({this.database = 'chalk'});

  final String database;

  static const _documents = 'documents';
  static const _snapshots = 'snapshots';
  static const _main = 'main';

  Future<web.IDBDatabase>? _db;
  bool _askedToPersist = false;

  @override
  Future<Map<String, dynamic>?> load() async {
    try {
      final text = await _get(_documents, _main);
      if (text == null || text.trim().isEmpty) return null;
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      // The same answer as an unreadable file on the phone: start from the
      // seed rather than leave the page stuck on a spinner.
      debugPrint('Could not read saved data: $e');
      return null;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> data) =>
      _put(_documents, _main, jsonEncode(data));

  @override
  Future<void> writeAutoBackup(
    Map<String, dynamic> data, {
    int keep = 10,
  }) async {
    unawaited(_askToPersist());
    await _put(
      _snapshots,
      Storage.snapshotName(DateTime.now()),
      jsonEncode(data),
    );
    try {
      final names = await _snapshotNames();
      if (names.length > keep) await _delete(_snapshots, names.skip(keep));
    } catch (e) {
      // A snapshot we cannot prune is not worth failing a workout over.
      debugPrint('Could not prune snapshots: $e');
    }
  }

  @override
  Future<List<Snapshot>> listAutoBackups() async => [
    for (final name in await _snapshotNames())
      Snapshot(name, () async {
        final text = await _get(_snapshots, name);
        if (text == null) throw const FormatException('Snapshot is gone');
        return text;
      }),
  ];

  /// The stored text exactly as it is, for the same reason as on the phone:
  /// a document from a newer version must not pass through this build's model
  /// on its way out.
  @override
  Future<XFile> copyForExport(String name) async {
    final text = await _get(_documents, _main);
    if (text == null) throw StateError('Nothing has been saved yet');
    return _inMemory(text, name, 'application/json');
  }

  @override
  Future<XFile> writeTextExport(String text, String name) async =>
      _inMemory(text, name, 'text/csv');

  @override
  Future<XFile> writeExport(Map<String, dynamic> data, String name) async =>
      _inMemory(
        const JsonEncoder.withIndent('  ').convert(data),
        name,
        'application/json',
      );

  static XFile _inMemory(String text, String name, String mimeType) =>
      XFile.fromData(utf8.encode(text), name: name, mimeType: mimeType);

  /// Asks the browser not to clear this site's data when space runs short.
  ///
  /// Chrome decides by itself, mostly on whether the page is installed; Firefox
  /// asks you. So it waits for a finished workout, when there is something
  /// worth keeping, instead of ambushing a first visit.
  Future<void> _askToPersist() async {
    if (_askedToPersist) return;
    _askedToPersist = true;
    try {
      final storage = web.window.navigator.storage;
      if ((await storage.persisted().toDart).toDart) return;
      final granted = (await storage.persist().toDart).toDart;
      debugPrint('Persistent storage ${granted ? 'granted' : 'refused'}');
    } catch (e) {
      debugPrint('Persistent storage unavailable: $e');
    }
  }

  // ------------------------------------------------------------- IndexedDB

  Future<web.IDBDatabase> _open() async {
    final pending = _db ??= _connect(database);
    try {
      return await pending;
    } catch (_) {
      // Let the next call try again rather than remembering the failure.
      if (identical(_db, pending)) _db = null;
      rethrow;
    }
  }

  static Future<web.IDBDatabase> _connect(String database) {
    final opened = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(database, 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      for (final store in [_documents, _snapshots]) {
        if (!db.objectStoreNames.contains(store)) db.createObjectStore(store);
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      opened.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      opened.completeError(
        StateError('IndexedDB would not open: ${request.error?.message}'),
      );
    }).toJS;
    return opened.future;
  }

  Future<String?> _get(String store, String key) async {
    final db = await _open();
    final request = db
        .transaction(store.toJS, 'readonly')
        .objectStore(store)
        .get(key.toJS);
    final result = await _result(request);
    return (result as JSString?)?.toDart;
  }

  Future<void> _put(String store, String key, String value) async {
    final db = await _open();
    final tx = db.transaction(store.toJS, 'readwrite');
    tx.objectStore(store).put(value.toJS, key.toJS);
    await _committed(tx);
  }

  Future<void> _delete(String store, Iterable<String> keys) async {
    final db = await _open();
    final tx = db.transaction(store.toJS, 'readwrite');
    final objects = tx.objectStore(store);
    for (final key in keys) {
      objects.delete(key.toJS);
    }
    await _committed(tx);
  }

  /// Newest first. The time is in the name, so name order is time order.
  Future<List<String>> _snapshotNames() async {
    final db = await _open();
    final request = db
        .transaction(_snapshots.toJS, 'readonly')
        .objectStore(_snapshots)
        .getAllKeys();
    final keys = await _result(request) as JSArray<JSString>;
    return [for (final key in keys.toDart) key.toDart]
      ..sort((a, b) => b.compareTo(a));
  }

  static Future<JSAny?> _result(web.IDBRequest request) {
    final done = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      done.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      done.completeError(
        StateError('IndexedDB request failed: ${request.error?.message}'),
      );
    }).toJS;
    return done.future;
  }

  /// Resolves once the browser has committed the write, not merely accepted
  /// it: the difference between "queued" and "saved".
  static Future<void> _committed(web.IDBTransaction tx) {
    final done = Completer<void>();
    void fail(String what) {
      if (done.isCompleted) return;
      done.completeError(StateError('$what: ${tx.error?.message}'));
    }

    tx.oncomplete = ((web.Event _) {
      if (!done.isCompleted) done.complete();
    }).toJS;
    tx.onerror = ((web.Event _) => fail('IndexedDB write failed')).toJS;
    tx.onabort = ((web.Event _) => fail('IndexedDB write aborted')).toJS;
    return done.future;
  }
}
