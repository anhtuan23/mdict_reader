import 'dart:ffi';

// TODO: support other platforms
DynamicLibrary openSqliteOnWindows() {
  return DynamicLibrary.open('test/assets/sqlite3.dll');
}
