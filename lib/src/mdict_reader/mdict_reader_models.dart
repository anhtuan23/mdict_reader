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
  static const filePathColumnName = 'filePath';
}

class MdictKey {
  MdictKey(this.word, this.offset, [this.length = -1]);

  factory MdictKey.fromRow(Row row) => MdictKey(
        row[wordColumnName],
        int.parse(row[offsetColumnName]),
        int.parse(row[lengthColumnName]),
      );

  String word;
  int offset;
  int length;

  static const tableName = 'keyTable';
  static const wordColumnName = 'word';
  static const offsetColumnName = 'offset';
  static const lengthColumnName = 'length';
  static const filePathColumnName = 'filePath';

  /// An aggregated comma separated string of all path when use with group by
  static const filePathsColumnName = 'filePaths';

  static String getWordFromRow(Row row) => row[wordColumnName];
  static String getFilePathFromRow(Row row) => row[filePathColumnName];
  static List<String> getFilePathsFromRow(Row row) =>
      (row[filePathsColumnName] as String).split(',');
}

abstract class MdictRecord {
  static const tableName = 'recordTable';
  static const compressedSizeColumnName = 'compressedSize';
  static const uncompressedSizeColumnName = 'uncompressedSize';
  static const filePathColumnName = 'filePath';
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
