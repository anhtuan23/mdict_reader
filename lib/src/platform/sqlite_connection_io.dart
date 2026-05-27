import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as native;

/// Opens the MDICT index database on native platforms.
///
/// When [dbPath] is `null`, callers get a temporary in-memory database for
/// tests or one-off work. Otherwise [dbPath] is a real filesystem path and
/// sqlite3 writes the index directly to disk.
Future<CommonDatabase> openMdictDatabase(String? dbPath) async {
  if (dbPath == null) return native.sqlite3.openInMemory();
  return native.sqlite3.open(dbPath);
}

/// Native sqlite3 writes directly to disk, so there is no browser-style virtual
/// filesystem cache to flush.
Future<void> flushMdictDatabase() async {}
