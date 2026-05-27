import 'package:sqlite3/wasm.dart';

const _sqliteWasmPath = 'sqlite3.wasm';
const _sqliteIndexedDbName = 'readdict_mdict_sqlite';

// Loading sqlite3.wasm is relatively expensive. Keep one shared instance for
// every dictionary manager created during this browser session.
Future<WasmSqlite3>? _sqliteFuture;
IndexedDbFileSystem? _fileSystem;

Future<WasmSqlite3> _sqlite() {
  return _sqliteFuture ??= _loadSqlite();
}

Future<WasmSqlite3> _loadSqlite() async {
  // The app must ship the sqlite3.dart release asset at web/sqlite3.wasm.
  // Generic sql.js WASM files are not compatible with package:sqlite3.
  final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse(_sqliteWasmPath));
  // Browser apps cannot write to an arbitrary path on the user's disk. sqlite3
  // therefore writes through a virtual file system backed by IndexedDB.
  _fileSystem = await IndexedDbFileSystem.open(dbName: _sqliteIndexedDbName);
  sqlite.registerVirtualFileSystem(_fileSystem!, makeDefault: true);
  return sqlite;
}

/// Opens the MDICT index database in the browser.
///
/// [dbPath] is still shaped like an absolute path because the rest of the
/// reader expects path strings. On web, that path is interpreted inside
/// sqlite3's IndexedDB virtual file system, not on the user's real filesystem.
Future<CommonDatabase> openMdictDatabase(String? dbPath) async {
  final sqlite = await _sqlite();
  if (dbPath == null) return sqlite.openInMemory();
  final normalizedPath = dbPath.startsWith('/') ? dbPath : '/$dbPath';
  return sqlite.open(normalizedPath);
}

/// Persists pending virtual filesystem writes into IndexedDB.
///
/// Native sqlite3 databases are flushed by the OS. The browser VFS batches
/// writes, so callers flush after index-building work to make the database
/// available after a reload.
Future<void> flushMdictDatabase() async {
  await _fileSystem?.flush();
}
