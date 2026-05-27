import 'package:sqlite3/common.dart';

/// Fallback used only if a future platform matches neither native IO nor web.
Future<CommonDatabase> openMdictDatabase(String? dbPath) {
  throw UnsupportedError('SQLite is not available on this platform.');
}

/// Fallback no-op matching the native/web SQLite API shape.
Future<void> flushMdictDatabase() async {}
