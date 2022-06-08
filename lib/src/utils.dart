import 'dart:io';

import 'package:path/path.dart' as p;

abstract class MdictHelpers {
  static String getDictNameFromPath(String mdxPath) =>
      p.basenameWithoutExtension(mdxPath).toLowerCase();

  static Future<String?> readFileContent(String? filePath) async {
    // * Check file.exists() of empty path cause CRASH:
    // * Stack dump aborted because InitialRegisterCheck failed
    if (filePath != null) {
      final file = File(filePath);
      if (file.existsSync()) {
        try {
          return await file.readAsString();
        } on FileSystemException catch (_) {
          // try to read file content with utf-16 encoding
          final bytes = file.readAsBytesSync();
          // Note that this assumes that the system's native endianness
          // is the same as the file's.
          final utf16CodeUnits = bytes.buffer.asUint16List();
          return String.fromCharCodes(utf16CodeUnits);
        }
      }
    }
    return Future.value();
  }
}

extension ListExt<E> on List<E> {
  List<E> addIfNotNull(E? newValue) {
    if (newValue != null) {
      add(newValue);
    }
    return this;
  }
}
