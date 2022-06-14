import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

// Sample header
// {
//     "generatedbyengineversion": 2.0,
//     "requiredengineversion": 2.0,
//     "format": "Html",
//     "keycasesensitive": "No",
//     "stripkey": "Yes",
//     "encrypted": 2,
//     "registerby": "EMail",
//     "description": "Description html",
//     "title": "CC-CEDICT",
//     "encoding": "UTF-8",
//     "creationdate": "2016-7-1",
//     "compact": "No",
//     "compat": "No",
//     "left2right": "Yes",
//     "datasourceformat": 107,
//     "stylesheet": "",
//     "_recordBlockOffsetKey": "[int]"
// }

abstract class MdictMeta {
  static const tableName = 'metaTable';
  static const keyColumnName = 'key';
  static const valueColumnName = 'value';
  static const fileNameColumnName = 'fileName';
}

class MdictKey {
  MdictKey(this.word, this.offset, [this.length = -1]);

  factory MdictKey.fromRow(Row row) => MdictKey(
        row[wordColumnName] as String,
        int.parse(row[offsetColumnName] as String),
        int.parse(row[lengthColumnName] as String),
      );

  String word;
  int offset;
  int length;

  static const tableName = 'keyTable';
  static const wordColumnName = 'word';
  static const offsetColumnName = 'offset';
  static const lengthColumnName = 'length';
  static const fileNameColumnName = 'fileName';

  /// An aggregated comma separated string of all path when use with group by
  static const fileNamesColumnName = 'fileNames';

  static String getWordFromRow(Row row) => row[wordColumnName] as String;
  static String getFileNameFromRow(Row row) =>
      row[fileNameColumnName] as String;
  static List<String> getFileNamesFromRow(Row row) =>
      (row[fileNamesColumnName] as String).split(',');
}

abstract class MdictRecord {
  static const tableName = 'recordTable';
  static const compressedSizeColumnName = 'compressedSize';
  static const uncompressedSizeColumnName = 'uncompressedSize';
  static const fileNameColumnName = 'fileName';
}

class IndexInfo {
  IndexInfo(
    this.metaInfo,
    this.keyList,
    this.recordsCompressedSizes,
    this.recordsUncompressedSizes,
  );

  final Map<String, String> metaInfo;
  final List<MdictKey> keyList;
  final Uint32List recordsCompressedSizes;
  final Uint32List recordsUncompressedSizes;
}

class MdictSearchResultLists {
  const MdictSearchResultLists(this.startsWithSet, this.containsSet);

  final Set<String> startsWithSet;
  final Set<String> containsSet;

  @override
  String toString() {
    return 'startsWithSet: $startsWithSet\ncontainsSet: $containsSet';
  }
}
