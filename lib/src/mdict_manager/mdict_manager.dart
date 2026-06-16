import 'dart:async';
import 'dart:typed_data';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_dictionary/mdict_dictionary.dart';
import 'package:mdict_reader/src/mdict_reader/mdict_reader_models.dart';
import 'package:mdict_reader/src/platform/sqlite_connection.dart';
import 'package:sqlite3/common.dart';

class MdictManager {
  MdictManager._(
    this._dictionaryList,
    this._db, [
    this._progressController,
  ]);
  final List<MdictDictionary> _dictionaryList;
  final CommonDatabase _db;
  // visible for testing
  CommonDatabase get dbForTest => _db;
  final StreamController<MdictProgress>? _progressController;
  Stream<MdictProgress>? get progressStream => _progressController?.stream;
  Map<String, String> get pathNameMap => {
    for (final dict in _dictionaryList) dict.mdxPath: dict.name,
  };
  static void _discardOldMdicts({
    required CommonDatabase db,
    required String fileNameColumnName,
    required String tableName,
    required List<String> fileNameExtList,
  }) {
    final conditionPlaceHolder = Iterable.generate(
      fileNameExtList.length,
      (_) => '?',
    ).join(',');
    db.execute(
      '''
        DELETE FROM $tableName
        WHERE $fileNameColumnName NOT IN ($conditionPlaceHolder) ;
      ''',
      fileNameExtList,
    );
  }

  /// visible for MdictDictionary test
  static void createTables({
    required CommonDatabase db,
    required Iterable<MdictFiles> mdictFilesIter,
    StreamController<MdictProgress>? progressController,
  }) {
    final allMdictFileNameExtList = mdictFilesIter.expand(
      (mdictFiles) {
        final mdxFileNameExt = MdictHelpers.getFileNameWithExtensionFromPath(
          mdictFiles.mdxPath,
        );
        final mddFileNameExt = mdictFiles.mddPath != null
            ? MdictHelpers.getFileNameWithExtensionFromPath(mdictFiles.mddPath!)
            : null;
        return mddFileNameExt == null
            ? [mdxFileNameExt]
            : [mdxFileNameExt, mddFileNameExt];
      },
    ).toList();
    progressController?.add(const MdictProgressManagerCreateMeta());
    db.execute(
      '''
        CREATE TABLE IF NOT EXISTS '${MdictMeta.tableName}' (
          ${MdictMeta.keyColumnName} TEXT NOT NULL,
          ${MdictMeta.valueColumnName} TEXT NOT NULL,
          ${MdictMeta.fileNameColumnName} TEXT NOT NULL
        );
      ''',
    );
    // Check if there are any old mdict in db
    progressController?.add(const MdictProgressManagerCountOld());
    final conditionPlaceHolder = Iterable.generate(
      allMdictFileNameExtList.length,
      (_) => '?',
    ).join(',');
    final resultSet = db.select(
      '''
        SELECT COUNT(1) FROM ${MdictMeta.tableName}
        WHERE ${MdictMeta.fileNameColumnName} NOT IN ($conditionPlaceHolder);
      ''',
      allMdictFileNameExtList,
    );
    final oldMdictCount = resultSet.first.columnAt(0) as int;
    final hasOldMdict = oldMdictCount > 0;
    if (hasOldMdict) {
      progressController?.add(
        MdictProgressManagerHasOld(
          oldMdictCount,
          allMdictFileNameExtList,
        ),
      );
      progressController?.add(
        const MdictProgressManagerDiscardOld(MdictMeta.tableName),
      );
      _discardOldMdicts(
        db: db,
        fileNameColumnName: MdictMeta.fileNameColumnName,
        tableName: MdictMeta.tableName,
        fileNameExtList: allMdictFileNameExtList,
      );
    }
    progressController?.add(const MdictProgressManagerCreateKey());
    db
      ..execute(
        '''
        CREATE TABLE IF NOT EXISTS '${MdictKey.tableName}' (
          ${MdictKey.wordColumnName} TEXT NOT NULL,
          ${MdictKey.offsetColumnName} TEXT NOT NULL,
          ${MdictKey.lengthColumnName} TEXT NOT NULL,
          ${MdictKey.fileNameColumnName} TEXT NOT NULL
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
          ON ${MdictKey.tableName} (${MdictKey.fileNameColumnName}, ${MdictKey.wordColumnName} COLLATE NOCASE);
        ''',
      );
    if (hasOldMdict) {
      progressController?.add(
        const MdictProgressManagerDiscardOld(MdictKey.tableName),
      );
      _discardOldMdicts(
        db: db,
        fileNameColumnName: MdictKey.fileNameColumnName,
        tableName: MdictKey.tableName,
        fileNameExtList: allMdictFileNameExtList,
      );
    }
    progressController?.add(const MdictProgressManagerCreateRecord());
    db
      ..execute(
        '''
          CREATE TABLE IF NOT EXISTS '${MdictRecord.tableName}' (
            ${MdictRecord.compressedSizeColumnName} BLOB NOT NULL,
            ${MdictRecord.uncompressedSizeColumnName} BLOB NOT NULL,
            ${MdictRecord.fileNameColumnName} TEXT NOT NULL
          );
        ''',
      )
      ..execute(
        '''
          CREATE INDEX IF NOT EXISTS idx_${MdictRecord.tableName} 
          ON ${MdictRecord.tableName} (${MdictRecord.fileNameColumnName});
        ''',
      );
    if (hasOldMdict) {
      progressController?.add(
        const MdictProgressManagerDiscardOld(MdictRecord.tableName),
      );
      _discardOldMdicts(
        db: db,
        fileNameColumnName: MdictRecord.fileNameColumnName,
        tableName: MdictRecord.tableName,
        fileNameExtList: allMdictFileNameExtList,
      );
    }
  }

  static Future<MdictManager> create({
    required Iterable<MdictFiles> mdictFilesIter,
    required String? dbPath,
    StreamController<MdictProgress>? progressController,
  }) async {
    final dictionaryList = <MdictDictionary>[];
    progressController?.add(const MdictProgressManagerOpenDb());
    final db = await openMdictDatabase(dbPath);
    createTables(
      db: db,
      mdictFilesIter: mdictFilesIter,
      progressController: progressController,
    );
    for (final mdictFiles in mdictFilesIter) {
      try {
        progressController?.add(
          MdictProgressManagerProcessing(
            MdictHelpers.getFileNameWithExtensionFromPath(mdictFiles.mdxPath),
          ),
        );
        final mdict = await MdictDictionary.create(
          mdictFiles: mdictFiles,
          db: db,
          progressController: progressController,
        );
        dictionaryList.add(mdict);
      } on Exception catch (e, stackTrace) {
        progressController?.add(MdictProgressError(e.toString(), stackTrace));
        print('Error with ${mdictFiles.mdxPath}: $e');
        print(stackTrace);
      }
    }
    await flushMdictDatabase();
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
          GROUP_CONCAT(${MdictKey.fileNameColumnName}) ${MdictKey.fileNamesColumnName}
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

  Future<List<SearchReturn>> search(
    String term, [
    List<String>? alternativeTerms,
  ]) async {
    var resultSet = await _multipleSearch([term]);
    // Fall back to alternative query expansions (such as unconjugated forms)
    // if the exact term yielded no matches.
    if (resultSet.isEmpty &&
        alternativeTerms != null &&
        alternativeTerms.isNotEmpty) {
      resultSet = await _multipleSearch(alternativeTerms);
    }
    final searchReturns = resultSet.map(
      (row) => SearchReturn.fromRow(row, pathNameMap),
    );
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
          MdictProgressManagerQuerying(word, dictionary.name),
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
    _progressController?.add(MdictProgressManagerFinishedQuerying(word));
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
    var newIndex_ = newIndex;
    // if move item toward the end,
    // newIndex decrease by 1 after removeAt oldIndex
    if (oldIndex < newIndex) {
      newIndex_ -= 1;
    }
    final item = _dictionaryList.removeAt(oldIndex);
    _dictionaryList.insert(newIndex_, item);
    return MdictManager._(_dictionaryList, _db);
  }

  /// Disposes all loaded dictionaries in the manager and closes the SQLite
  /// database connection. This must be called when unloading the dictionary
  /// manager (e.g., during application shutdown or dictionary reloads) to
  /// cleanly close all active SQLite connections and underlying file handles.
  Future<void> dispose() async {
    for (final dictionary in _dictionaryList) {
      await dictionary.dispose();
    }
    _db.close();
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
