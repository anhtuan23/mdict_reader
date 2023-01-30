import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/parser.dart' show parseFragment;
import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_reader/input_stream.dart';
import 'package:mdict_reader/src/mdict_reader/mdict_reader_models.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/api.dart';
import 'package:quiver/iterables.dart';
import 'package:sqlite3/sqlite3.dart';

part 'mdict_reader_helper.dart';
part 'mdict_reader_init_helper.dart';

class MdictReader {
  MdictReader({
    required this.path,
    required this.fileName,
    required Database db,
    required Map<String, String> header,
    required Uint32List recordsCompressedSizes,
    required Uint32List recordsUncompressedSizes,
  })  : _header = header,
        _db = db,
        _recordsCompressedSizes = recordsCompressedSizes,
        _recordsUncompressedSizes = recordsUncompressedSizes,
        _recordBlockOffset = int.parse(header[recordBlockOffsetKey]!),
        name = header['title'];

  static const recordBlockOffsetKey = '_recordBlockOffsetKey';

  final String path;
  final String fileName;
  final Map<String, String> _header;
  final Uint32List _recordsCompressedSizes;
  final Uint32List _recordsUncompressedSizes;
  final int _recordBlockOffset;
  final String? name;
  final Database _db;

  bool get isMdd => path.endsWith('.mdd');

  bool get _isUtf8 => _header['encoding'] == 'UTF-8';

  /// **************************************************

  /// * Should only be used in a mdx reader
  /// Return of result html
  Future<String> queryMdx(String keyWord) async {
    if (isMdd) throw UnsupportedError('Only call queryMdx in a mdx file');

    // Query result might contains a reference loop through @@@LINK=
    // therefore we must provide the result map to remember queried words
    final resultMap = <String, List<String>>{};
    await _queryHtmls(keyWord, resultMap);

    final definitionHtmlString = resultMap.values
        .expand((htmlList) => htmlList)
        .join('<p> ********** </p>');
    return definitionHtmlString;
  }

  /// Find Html definitions of a [keyWord]
  /// Can be called recursively to resolve `@@@LINK=`
  Future<void> _queryHtmls(
    String keyWord,
    Map<String, List<String>> resultMap,
  ) async {
    final List<MdictKey> mdictKeys;

    final resultSet = _db.select(
      // since index on [word] is created with COLLATE NOCASE
      // comparison must use LIKE, or index on [word] won't be used
      '''
        SELECT ${MdictKey.wordColumnName}, ${MdictKey.offsetColumnName}, ${MdictKey.lengthColumnName} 
        FROM ${MdictKey.tableName} 
        WHERE ${MdictKey.fileNameColumnName} = ?
          AND ${MdictKey.wordColumnName} LIKE ? 
      ''',
      [fileName, keyWord.trim()],
    );
    mdictKeys = resultSet.map((row) => MdictKey.fromRow(row)).toList();

    resultMap[keyWord] = [];
    for (final mdictKey in mdictKeys) {
      final htmlString = await _readRecord(
        mdictKey.offset,
        mdictKey.length,
      ) as String;

      if (htmlString.startsWith('@@@LINK=')) {
        final keyWord = htmlString.substring(8).trim();
        // Query result might contains a reference loop through @@@LINK=
        if (!resultMap.containsKey(keyWord)) {
          await _queryHtmls(keyWord, resultMap);
        }
      } else {
        resultMap[keyWord]!.add(htmlString.trim());
      }
    }
  }

  Future<Uint8List?> queryMdd(String resourceKey) async {
    var localResourceKey = resourceKey;

    if (!isMdd) throw UnsupportedError('Only call queryMdd in a mdd file');

    localResourceKey = localResourceKey.trim();

    final resultSet = _db.select(
      '''
        SELECT ${MdictKey.wordColumnName}, ${MdictKey.offsetColumnName}, ${MdictKey.lengthColumnName}
        FROM ${MdictKey.tableName}
        WHERE ${MdictKey.fileNameColumnName} = ? 
          AND (${MdictKey.wordColumnName} LIKE ?
               OR ${MdictKey.wordColumnName} LIKE ?
              ) 
      ''',
      [
        fileName,
        '$localResourceKey%',
        '\\$localResourceKey%',
      ],
    );

    for (final row in resultSet) {
      final key = MdictKey.fromRow(row);
      final data = await _readRecord(
        key.offset,
        key.length,
      ) as Uint8List;
      return data;
    }
    return Future.value();
  }

  /// replace resource url in cssString with base64 encoded data
  Future<String> replaceCssUrl(String cssString) async {
    var localCssString = cssString;
    final urlContentMatches = MdictReaderHelper.cssUrlExtractor(localCssString);
    for (final match in urlContentMatches) {
      final url = match.group(0);
      if (url == null) continue;

      var extension = p.extension(url).toLowerCase();
      extension = extension.replaceFirst('.', '');
      if (extension.isEmpty ||
          !['png', 'jpg', 'jpeg', 'gif'].contains(extension)) continue;

      final intData = await queryMdd(url);
      if (intData == null) continue;

      // print('replace $url in css with base64 encoded data');

      final base64Data = base64.encode(intData);

      localCssString = localCssString.replaceRange(
        match.start,
        match.end,
        'data:image/$extension;base64,$base64Data',
      );
    }
    return localCssString;
  }

  /// Extract css/js content from mdd file if available
  /// [getCss] is true if we need to extract css content
  ///          is false if we need to extract js content
  Future<String?> extractScriptContent({required bool getCss}) async {
    if (!isMdd) {
      throw UnsupportedError('Only try to extract css/js from mdd file');
    }

    final extensionMatcher = getCss ? '%.css' : '%.js';

    final resultSet = _db.select(
      '''
        SELECT ${MdictKey.wordColumnName} 
        FROM '${MdictKey.tableName}' 
        WHERE ${MdictKey.fileNameColumnName} = ? 
          AND ${MdictKey.wordColumnName} LIKE ? 
      ''',
      [fileName, extensionMatcher],
    );

    for (final row in resultSet) {
      final scriptKey = row[MdictKey.wordColumnName] as String;
      final data = await queryMdd(scriptKey);
      if (data != null) {
        return _isUtf8
            ? const Utf8Decoder().convert(data)
            // assume to be utf-16
            : String.fromCharCodes(data);
      }
    }
    return Future.value();
  }

  Future<dynamic> _readRecord(
    int offset,
    int length,
  ) async {
    var compressedOffset = 0;
    var uncompressedOffset = 0;
    var compressedSize = 0;
    var uncompressedSize = 0;
    for (var i = 0; i < _recordsCompressedSizes.length; i++) {
      compressedSize = _recordsCompressedSizes[i];
      uncompressedSize = _recordsUncompressedSizes[i];
      if ((uncompressedOffset + uncompressedSize) > offset) {
        break;
      }
      uncompressedOffset += uncompressedSize;
      compressedOffset += compressedSize;
    }
    final file = await File(path).open();
    await file.setPosition(_recordBlockOffset + compressedOffset);
    final block = await file.read(compressedSize);
    await file.close();
    final blockIn = MdictReaderHelper._decompressBlock(block);
    await blockIn.skip(offset - uncompressedOffset);
    if (isMdd) {
      final recordBlock = await blockIn.toUint8List();
      if (length > 0) {
        return recordBlock.sublist(0, length);
      } else {
        return recordBlock;
      }
    } else {
      return blockIn.readString(size: length, utf8: _isUtf8);
    }
  }
}
