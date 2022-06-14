import 'dart:ffi';

DynamicLibrary openSqliteOnWindows() {
  return DynamicLibrary.open('test/assets/sqlite3.dll');
}
