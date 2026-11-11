import 'storage.dart';

/// The store a phone build uses. The browser build imports `storage_web.dart`
/// in this file's place, which answers with IndexedDB instead.
Storage platformStorage() => Storage();
