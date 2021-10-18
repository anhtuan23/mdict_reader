import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mdict_reader/src/mdict_manager/mdict_manager_models.dart';
import 'package:mdict_reader/src/mdict_reader/mdict_reader_models.dart';
import 'package:mdict_reader/src/utils.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_reader/input_stream.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:quiver/iterables.dart';
import 'package:pointycastle/api.dart';
import 'package:path/path.dart' as p;

part 'mdict_reader_helper.dart';
part 'mdict_reader_init_helper.dart';

class MdictReader {
  MdictReader({
    required this.path,
    required Database db,
    required Map<String, String> header,
    required Uint32List recordsCompressedSizes,
    required Uint32List recordsUncompressedSizes,
  })  : _header = header,
        _db = db,
        _recordsCompressedSizes = recordsCompressedSizes,
        _recordsUncompressedSizes = recordsUncompressedSizes,
        _recordBlockOffset = int.parse(header[recordBlockOffsetKey]!),
        name = header['title'] ?? MdictHelpers.getDictNameFromPath(path);

  static const recordBlockOffsetKey = '_recordBlockOffsetKey';

  final String path;
  final Map<String, String> _header;
  final Uint32List _recordsCompressedSizes;
  final Uint32List _recordsUncompressedSizes;
  final int _recordBlockOffset;
  final String name;
  final Database _db;

  bool get isMdd => path.endsWith('.mdd');

  /// **************************************************

  /// * Should only be used in a mdx reader
  /// Return of result html
  Future<String> queryMdx(String keyWord) async {
    if (isMdd) throw UnsupportedError('Only call queryMdx in a mdx file');

    final definitionHtmlString =
        (await _queryHtmls(keyWord)).join('<p> ********** </p>');
    return definitionHtmlString;
  }

  /// Find Html definitions of a [keyWord]
  /// Can be called recursively to resolve `@@@LINK=`
  Future<List<String>> _queryHtmls(String keyWord) async {
    var htmlStrings = <String>[];

    final List<MdictKey> mdictKeys;

    final resultSet = _db.select(
      // since index on [word] is created with COLLATE NOCASE
      // comparison must use LIKE, or index on [word] won't be used
      '''
        SELECT ${MdictKey.wordColumnName}, ${MdictKey.offsetColumnName}, ${MdictKey.lengthColumnName} 
        FROM ${MdictKey.tableName} 
        WHERE ${MdictKey.filePathColumnName} = ?
          AND ${MdictKey.wordColumnName} LIKE ? 
      ''',
      [path, keyWord.trim()],
    );
    mdictKeys = resultSet.map((row) => MdictKey.fromRow(row)).toList();
    // }

    for (var mdictKey in mdictKeys) {
      String htmlString = await _readRecord(
        mdictKey.offset,
        mdictKey.length,
      );

      if (htmlString.startsWith('@@@LINK=')) {
        final _keyWord = htmlString.substring(8).trim();
        htmlStrings.addAll(await _queryHtmls(_keyWord));
      } else {
        htmlStrings.add(htmlString.trim());
      }
    }
    return htmlStrings;
  }

  Future<Uint8List?> queryMdd(String resourceKey) async {
    if (!isMdd) throw UnsupportedError('Only call queryMdd in a mdd file');

    resourceKey = resourceKey.trim();

    final resultSet = _db.select(
      '''
        SELECT ${MdictKey.wordColumnName}, ${MdictKey.offsetColumnName}, ${MdictKey.lengthColumnName}
        FROM ${MdictKey.tableName}
        WHERE ${MdictKey.filePathColumnName} = ? 
          AND (${MdictKey.wordColumnName} LIKE ?
               OR ${MdictKey.wordColumnName} LIKE ?
              ) 
      ''',
      [
        path,
        '$resourceKey%',
        '\\$resourceKey%',
      ],
    );

    for (var row in resultSet) {
      final key = MdictKey.fromRow(row);
      final Uint8List data = await _readRecord(
        key.offset,
        key.length,
      );
      return data;
    }
  }

  /// Extract css content from mdd file if available
  Future<String?> extractCss() async {
    if (!isMdd) throw UnsupportedError('Only try to extract css from mdd file');

    final resultSet = _db.select(
      '''SELECT ${MdictKey.wordColumnName} 
         FROM '${MdictKey.tableName}' 
         WHERE ${MdictKey.filePathColumnName} = ? 
          AND ${MdictKey.wordColumnName} LIKE ? 
      ''',
      [path, '%.css'],
    );

    for (var row in resultSet) {
      final cssKey = row[MdictKey.wordColumnName];
      final data = await queryMdd(cssKey);
      if (data != null) {
        return const Utf8Decoder().convert(data);
      }
    }
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
    var _in = await File(path).open();
    await _in.setPosition(_recordBlockOffset + compressedOffset);
    var block = await _in.read(compressedSize);
    await _in.close();
    var blockIn = MdictReaderHelper._decompressBlock(block);
    await blockIn.skip(offset - uncompressedOffset);
    if (isMdd) {
      var recordBlock = await blockIn.toUint8List();
      if (length > 0) {
        return recordBlock.sublist(0, length);
      } else {
        return recordBlock;
      }
    } else {
      var utf8 = _header['encoding'] == 'UTF-8';
      return blockIn.readString(size: length, utf8: utf8);
    }
  }
}
