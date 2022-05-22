import 'dart:io';

import 'package:path/path.dart' as p;

abstract class MdictHelpers {
  static String getDictNameFromPath(String mdxPath) =>
      p.basenameWithoutExtension(mdxPath).toLowerCase();

  static Future<String?> readFileContent(String? filePath) async {
    // * Check file.exists() of empty path cause CRASH: Stack dump aborted because InitialRegisterCheck failed
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        return file.readAsString();
      }
    }
    return Future.value(null);
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
