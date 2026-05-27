import 'dart:convert';
import 'package:mdict_reader/src/platform/mdict_random_access_file.dart';
import 'package:path/path.dart' as p;

abstract class MdictHelpers {
  static String getFileNameFromPath(String mdxPath, {bool toLowerCase = true}) {
    final baseName = p.basenameWithoutExtension(mdxPath);
    return toLowerCase ? baseName.toLowerCase() : baseName;
  }

  /// Get unique file name for used in db
  static String getFileNameWithExtensionFromPath(String mdxPath) {
    return p.basename(mdxPath).toLowerCase();
  }

  static Future<String?> readFileContent(String? filePath) async {
    // * Check file.exists() of empty path cause CRASH:
    // * Stack dump aborted because InitialRegisterCheck failed
    if (filePath != null) {
      if (await mdictFileReferenceExists(filePath)) {
        try {
          final bytes = await readMdictFileBytes(filePath);
          if (bytes == null) return null;
          return const Utf8Decoder().convert(bytes);
        } on FormatException catch (_) {
          // try to read file content with utf-16 encoding
          final bytes = await readMdictFileBytes(filePath);
          if (bytes == null) return null;
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
