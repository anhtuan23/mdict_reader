import 'package:sqlite3/common.dart';

// Global injectable callbacks for web/non-IO platforms.
// The caller (like mdict_flutter) registers these functions at startup.
Future<CommonDatabase> Function(String? dbPath)? mdictDatabaseOpener;
Future<void> Function()? mdictDatabaseFlusher;

Future<CommonDatabase> openMdictDatabase(String? dbPath) async {
  final opener = mdictDatabaseOpener;
  if (opener != null) {
    return opener(dbPath);
  }
  throw UnsupportedError(
    'Database access is not available on this platform. '
    'Ensure you set mdictDatabaseOpener.',
  );
}

Future<void> flushMdictDatabase() async {
  final flusher = mdictDatabaseFlusher;
  if (flusher != null) {
    await flusher();
  }
}
