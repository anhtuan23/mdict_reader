// Exposes a single SQLite-opening API while hiding the platform-specific
// implementation details.
//
// Native platforms can open a normal filesystem database. Browser builds cannot
// use `dart:io`, so they load `sqlite3.wasm` and store the database in
// IndexedDB through sqlite3's virtual file system.
export 'sqlite_connection_stub.dart'
    if (dart.library.io) 'sqlite_connection_io.dart'
    if (dart.library.js_interop) 'sqlite_connection_web.dart';
