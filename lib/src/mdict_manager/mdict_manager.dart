import 'dart:async';
import 'dart:typed_data';

import 'package:html_unescape/html_unescape_small.dart';
import 'package:japanese_conjugation/japanese_conjugation.dart';
import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_dictionary/mdict_dictionary.dart';
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
  // visible for testing
  Database get dbForTest => _db;
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
    final filePathsList = filePaths.map((e) => "'$e'").toList();
    final conditionPlaceHolder =
        Iterable.generate(filePathsList.length, (_) => '?').join(',');
    db.execute(
      '''
        DELETE FROM $tableName
        WHERE $filePathColumnName NOT IN ($conditionPlaceHolder) ;
      ''',
      filePathsList,
    );
  }

  /// visible for MdictDictionary test
  static void createTables({
    required Database db,
    required Iterable<MdictFiles> mdictFilesIter,
    StreamController<MdictProgress>? progressController,
  }) {
    final allMdictFilePaths = mdictFilesIter
        .expand(
          (mdictFiles) => [mdictFiles.mdxPath].addIfNotNull(mdictFiles.mddPath),
        )
        .toList();
    progressController?.add(const MdictProgress.mdictManagerCreateMeta());
    db.execute(
      '''
        CREATE TABLE IF NOT EXISTS '${MdictMeta.tableName}' (
          ${MdictMeta.keyColumnName} TEXT NOT NULL,
          ${MdictMeta.valueColumnName} TEXT NOT NULL,
          ${MdictMeta.filePathColumnName} TEXT NOT NULL
        );
      ''',
    );

    // Check if there are any old mdict in db
    progressController?.add(const MdictProgress.mdictManagerCountOld());
    final conditionPlaceHolder =
        Iterable.generate(allMdictFilePaths.length, (_) => '?').join(',');
    final resultSet = db.select(
      '''
        SELECT COUNT(1) FROM ${MdictMeta.tableName}
        WHERE ${MdictMeta.filePathColumnName} NOT IN ($conditionPlaceHolder);
      ''',
      allMdictFilePaths,
    );
    final oldMdictCount = resultSet.first.columnAt(0) as int;
    final hasOldMdict = oldMdictCount > 0;

    if (hasOldMdict) {
      progressController?.add(
        MdictProgress.mdictManagerHasOld(oldMdictCount, allMdictFilePaths),
      );

      progressController?.add(
        MdictProgress.mdictManagerDiscardOld(MdictMeta.tableName),
      );
      _discardOldMdicts(
        db: db,
        filePathColumnName: MdictMeta.filePathColumnName,
        tableName: MdictMeta.tableName,
        filePaths: allMdictFilePaths,
      );
    }

    progressController?.add(const MdictProgress.mdictManagerCreateKey());
    db
      ..execute(
        '''
        CREATE TABLE IF NOT EXISTS '${MdictKey.tableName}' (
          ${MdictKey.wordColumnName} TEXT NOT NULL,
          ${MdictKey.offsetColumnName} TEXT NOT NULL,
          ${MdictKey.lengthColumnName} TEXT NOT NULL,
          ${MdictKey.filePathColumnName} TEXT NOT NULL
        );
        ''',
      )
      // COLLATE NOCASE helps LIKE operate on index https://stackoverflow.com/a/8586390/4116924
      ..execute(
        '''
          CREATE INDEX IF NOT EXISTS idx_${MdictKey.tableName}_word 
          ON ${MdictKey.tableName} (${MdictKey.wordColumnName} COLLATE NOCASE);
        ''',
      )
      ..execute(
        '''
          CREATE INDEX IF NOT EXISTS idx_${MdictKey.tableName}_file_word
          ON ${MdictKey.tableName} (${MdictKey.filePathColumnName}, ${MdictKey.wordColumnName} COLLATE NOCASE);
        ''',
      );

    if (hasOldMdict) {
      progressController?.add(
        MdictProgress.mdictManagerDiscardOld(MdictKey.tableName),
      );
      _discardOldMdicts(
        db: db,
        filePathColumnName: MdictKey.filePathColumnName,
        tableName: MdictKey.tableName,
        filePaths: allMdictFilePaths,
      );
    }

    progressController?.add(const MdictProgress.mdictManagerCreateRecord());
    db
      ..execute(
        '''
          CREATE TABLE IF NOT EXISTS '${MdictRecord.tableName}' (
            ${MdictRecord.compressedSizeColumnName} BLOB NOT NULL,
            ${MdictRecord.uncompressedSizeColumnName} BLOB NOT NULL,
            ${MdictRecord.filePathColumnName} TEXT NOT NULL
          );
        ''',
      )
      ..execute(
        '''
          CREATE INDEX IF NOT EXISTS idx_${MdictRecord.tableName} 
          ON ${MdictRecord.tableName} (${MdictRecord.filePathColumnName});
        ''',
      );

    if (hasOldMdict) {
      progressController?.add(
        MdictProgress.mdictManagerDiscardOld(MdictRecord.tableName),
      );
      _discardOldMdicts(
        db: db,
        filePathColumnName: MdictRecord.filePathColumnName,
        tableName: MdictRecord.tableName,
        filePaths: allMdictFilePaths,
      );
    }
  }

  static Future<MdictManager> create({
    required Iterable<MdictFiles> mdictFilesIter,
    required String? dbPath,
    StreamController<MdictProgress>? progressController,
  }) async {
    final dictionaryList = <MdictDictionary>[];

    progressController?.add(const MdictProgress.mdictManagerOpenDb());
    final Database db;
    if (dbPath == null) {
      db = sqlite3.openInMemory();
    } else {
      db = sqlite3.open(dbPath);
    }

    createTables(
      db: db,
      mdictFilesIter: mdictFilesIter,
      progressController: progressController,
    );

    for (final mdictFiles in mdictFilesIter) {
      try {
        final mdxFileName =
            MdictHelpers.getDictNameFromPath(mdictFiles.mdxPath);
        progressController
            ?.add(MdictProgress.mdictManagerProcessing(mdxFileName));
        final mdict = await MdictDictionary.create(
          mdictFiles: mdictFiles,
          db: db,
          progressController: progressController,
        );
        dictionaryList.add(mdict);
      } catch (e, stackTrace) {
        progressController?.add(MdictProgress.error(e.toString(), stackTrace));
        print('Error with ${mdictFiles.mdxPath}: $e');
        print(stackTrace);
      }
    }

    return MdictManager._(dictionaryList, db, progressController);
  }

  Future<ResultSet> _multipleSearch(List<String> terms) async {
    if (terms.isEmpty) return ResultSet([], [], []);
    final whereConditions = Iterable.generate(
      terms.length,
      (_) => '(${MdictKey.wordColumnName} LIKE ?)',
    );
    final whereClause = whereConditions.join(' OR ');
    final resultSet = _db.select(
      '''
        SELECT 
          ${MdictKey.wordColumnName},
          GROUP_CONCAT(${MdictKey.filePathColumnName}) ${MdictKey.filePathsColumnName}
        FROM ${MdictKey.tableName} 
        WHERE $whereClause
        GROUP BY ${MdictKey.wordColumnName}
        ORDER BY ${MdictKey.wordColumnName} COLLATE NOCASE
        LIMIT 100;
      ''',
      terms.map((term) => '${term.trim()}%').toList(),
    );

    return resultSet;
  }

  Future<List<SearchReturn>> search(String term) async {
    var resultSet = await _multipleSearch([term]);

    // Try to unconjugate for Japanese with no result is found
    if (resultSet.isEmpty) {
      resultSet = await _multipleSearch(
        Conjugator.unconjugateFlatten(term).map((e) => e.word).toList(),
      );
    }

    final searchReturns =
        resultSet.map((row) => SearchReturn.fromRow(row, pathNameMap));

    return searchReturns.toList();
  }

  /// [searchDictMdxPaths] narrow down which dictionary to query if provided
  Future<List<QueryReturn>> query(
    String word, [
    Set<String>? searchDictMdxPaths,
  ]) async {
    final results = <QueryReturn>[];
    for (final dictionary in _dictionaryList) {
      if (searchDictMdxPaths?.contains(dictionary.mdxPath) ?? true) {
        _progressController?.add(
          MdictProgress.mdictManagerQuerying(word, dictionary.name),
        );
        final htmlCssJsList = await dictionary.queryMdx(word);

        if (htmlCssJsList[0].isNotEmpty) {
          results.add(
            QueryReturn(
              word,
              dictionary.name,
              dictionary.mdxPath,
              htmlCssJsList[0],
              htmlCssJsList[1],
              htmlCssJsList[2],
            ),
          );
        }
      }
    }
    _progressController?.add(MdictProgress.mdictManagerFinishedQuerying(word));
    return results;
  }

  /// [mdxPath] act as a key when we want to query resource
  /// from a specific dictionary
  Future<Uint8List?> queryResource(
    String resourceUri,
    String? mdxPath,
  ) async {
    final resourceKey = _parseResourceUri(resourceUri);
    for (final dictionary in _dictionaryList) {
      if (mdxPath != null && mdxPath != dictionary.mdxPath) continue;
      final data = await dictionary.queryResource(resourceKey);
      if (data != null) return data;
    }
    return Future.value();
  }

  MdictManager reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return this;

    var _newIndex = newIndex;
    // if move item toward the end,
    // newIndex decrease by 1 after removeAt oldIndex
    if (oldIndex < newIndex) {
      _newIndex -= 1;
    }

    final item = _dictionaryList.removeAt(oldIndex);
    _dictionaryList.insert(_newIndex, item);
    return MdictManager._(_dictionaryList, _db);
  }

  void dispose() {
    _db.dispose();
  }
}

final _unescaper = HtmlUnescape();

/// Example [uriStr]: sound://media/english/us_pron/u/u_s/u_s__/u_s__1_us_2_abbr.mp3
String _parseResourceUri(String uriStr) {
  final text = _unescaper.convert(uriStr);
  final uri = Uri.parse(text);
  final key = Uri.decodeFull('/${uri.host}${uri.path}');
  return key.replaceAll('/', r'\');
}
