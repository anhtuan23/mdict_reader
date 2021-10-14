import 'dart:async';
import 'dart:typed_data';

import 'package:html_unescape/html_unescape_small.dart';
import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_dictionary/mdict_dictionary.dart';
import 'package:mdict_reader/src/mdict_manager/mdict_manager_models.dart';
import 'package:mdict_reader/src/mdict_reader/mdict_reader_models.dart';
import 'package:sqlite3/sqlite3.dart';

class MdictManager {
  MdictManager._(
    this._dictionaryList,
    this._db, [
    this._progressController,
  ]);

  final List<MdictDictionary> _dictionaryList;
  final Database _db;
  final StreamController<MdictProgress>? _progressController;
  Stream<MdictProgress>? get progressStream => _progressController?.stream;

  Map<String, String> get pathNameMap =>
      {for (final dict in _dictionaryList) dict.mdxPath: dict.name};

  static void _discardOldMdicts({
    required List<String> filePaths,
    required Database db,
    required String tableName,
    required String filePathColumnName,
  }) {
    var filePathsList = filePaths.map((e) => "'$e'").toList();

    final paths = filePathsList.join(',');

    db.execute('''
      DELETE FROM $tableName
      WHERE $filePathColumnName NOT IN (${filePathsList.join(',')}) ;
    ''');
  }

  /// visible for MdictDictionary test
  static void createTables({
    required Database db,
    required Iterable<MdictFiles> mdictFilesIter,
  }) {
    final allMdictFilePaths = mdictFilesIter
        .expand((mdictFiles) =>
            [mdictFiles.mdxPath].addIfNotNull(mdictFiles.mddPath))
        .toList();
    db.execute('''
      CREATE TABLE IF NOT EXISTS '${MdictMeta.tableName}' (
        ${MdictMeta.keyColumnName} TEXT NOT NULL,
        ${MdictMeta.valueColumnName} TEXT NOT NULL,
        ${MdictMeta.filePathColumnName} TEXT NOT NULL
      );
    ''');
    _discardOldMdicts(
      db: db,
      filePathColumnName: MdictMeta.filePathColumnName,
      tableName: MdictMeta.tableName,
      filePaths: allMdictFilePaths,
    );

    db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS '${MdictKey.tableName}' USING fts5(
        ${MdictKey.wordColumnName},
        ${MdictKey.offsetColumnName} UNINDEXED,
        ${MdictKey.lengthColumnName} UNINDEXED,
        ${MdictKey.filePathColumnName},
      );
      ''');
    _discardOldMdicts(
      db: db,
      filePathColumnName: MdictKey.filePathColumnName,
      tableName: MdictKey.tableName,
      filePaths: allMdictFilePaths,
    );

    db.execute('''
      CREATE TABLE IF NOT EXISTS '${MdictRecord.tableName}' (
        ${MdictRecord.compressedSizeColumnName} BLOB NOT NULL,
        ${MdictRecord.uncompressedSizeColumnName} BLOB NOT NULL,
        ${MdictRecord.filePathColumnName} TEXT NOT NULL
      );
    ''');
    db.execute('''
      CREATE INDEX IF NOT EXISTS idx_${MdictRecord.tableName} 
      ON ${MdictRecord.tableName} (${MdictRecord.filePathColumnName});
    ''');
    _discardOldMdicts(
      db: db,
      filePathColumnName: MdictRecord.filePathColumnName,
      tableName: MdictRecord.tableName,
      filePaths: allMdictFilePaths,
    );
  }

  static Future<MdictManager> create({
    required Iterable<MdictFiles> mdictFilesIter,
    required String? dbPath,
    StreamController<MdictProgress>? progressController,
  }) async {
    final dictionaryList = <MdictDictionary>[];

    progressController?.add(const MdictProgress('Opening index database ...'));
    final Database db;
    if (dbPath == null) {
      db = sqlite3.openInMemory();
    } else {
      db = sqlite3.open(dbPath);
    }

    createTables(db: db, mdictFilesIter: mdictFilesIter);

    for (var mdictFiles in mdictFilesIter) {
      try {
        final mdxFileName =
            MdictHelpers.getDictNameFromPath(mdictFiles.mdxPath);
        progressController?.add(MdictProgress('Processing $mdxFileName ...'));
        final mdict = await MdictDictionary.create(
          mdictFiles: mdictFiles,
          db: db,
          progressController: progressController,
        );
        dictionaryList.add(mdict);
      } catch (e, stackTrace) {
        print('Error with ${mdictFiles.mdxPath}: $e');
        print(stackTrace);
      }
    }

    return MdictManager._(dictionaryList, db, progressController);
  }

  Future<List<SearchReturn>> search(String term) async {
    final resultSet = _db.select(
      '''
        SELECT 
          ${MdictKey.wordColumnName},
          GROUP_CONCAT(${MdictKey.filePathColumnName}) ${MdictKey.filePathsColumnName}
        FROM ${MdictKey.tableName} 
        WHERE ${MdictKey.wordColumnName} MATCH ?
        GROUP BY ${MdictKey.wordColumnName}
        ORDER BY ${MdictKey.wordColumnName}
      ''',
      [term],
    );

    final searchReturns =
        resultSet.map((row) => SearchReturn.fromRow(row, pathNameMap));

    return searchReturns.take(100).toList();
  }

  /// [searchDictMdxPath] narrow down which dictionary to query if provided
  Future<List<QueryReturn>> query(
    String word, [
    Set<String>? searchDictMdxPaths,
  ]) async {
    final results = <QueryReturn>[];
    for (var dictionary in _dictionaryList) {
      if (searchDictMdxPaths?.contains(dictionary.mdxPath) ?? true) {
        _progressController?.add(
            MdictProgress('Querying for $word in ${dictionary.name} ...'));
        final htmlCssList = await dictionary.queryMdx(word);

        if (htmlCssList[0].isNotEmpty) {
          results.add(
            QueryReturn(
              word,
              dictionary.name,
              dictionary.mdxPath,
              htmlCssList[0],
              htmlCssList[1],
            ),
          );
        }
      }
    }
    _progressController?.add(MdictProgress('Finished querying for $word ...'));
    return results;
  }

  /// [mdxPath] act as a key when we want to query resource from a specific dictionary
  Future<Uint8List?> queryResource(
    String resourceUri,
    String? mdxPath,
  ) async {
    final resourceKey = _parseResourceUri(resourceUri);
    for (var dictionary in _dictionaryList) {
      if (mdxPath != null && mdxPath != dictionary.mdxPath) continue;
      final data = await dictionary.queryResource(resourceKey);
      if (data != null) return data;
    }
  }

  MdictManager reOrder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return this;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _dictionaryList.removeAt(oldIndex);
    _dictionaryList.insert(newIndex, item);
    return MdictManager._(_dictionaryList, _db);
  }

  void dispose() {
    _db.dispose();
  }
}

final _unescaper = HtmlUnescape();

/// Example [uriStr]: sound://media/english/us_pron/u/u_s/u_s__/u_s__1_us_2_abbr.mp3
String _parseResourceUri(String uriStr) {
  var text = _unescaper.convert(uriStr);
  final uri = Uri.parse(text);
  final key = Uri.decodeFull('/${uri.host}${uri.path}');
  return key.replaceAll('/', '\\');
}
