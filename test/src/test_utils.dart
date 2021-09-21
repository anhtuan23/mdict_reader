import 'dart:ffi';
class Utils{}
DynamicLibrary openSqliteOnWindows() {
  return DynamicLibrary.open('test/assets/sqlite3.dll');
}
