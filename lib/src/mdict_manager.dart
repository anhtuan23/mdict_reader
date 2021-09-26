import 'dart:async';
import 'dart:typed_data';

import 'package:html_unescape/html_unescape_small.dart';
import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_dictionary.dart';
import 'package:mdict_reader/src/mdict_manager_models.dart';
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

  static Iterable<String> _getTableNames(Database db) {
    final tableResultSet =
        db.select("SELECT name FROM sqlite_master WHERE type='table'");
    return tableResultSet.map((e) => e['name']);
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

    progressController?.add(const MdictProgress('Getting table names ...'));
    final currentTableNames = _getTableNames(db);

    for (var mdictFiles in mdictFilesIter) {
      try {
        final mdxFileName =
            MdictHelpers.getDictNameFromPath(mdictFiles.mdxPath);
        progressController?.add(MdictProgress('Processing $mdxFileName ...'));
        final mdict = await MdictDictionary.create(
          mdictFiles: mdictFiles,
          currentTableNames: currentTableNames,
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
    final startsWithMap = <String, SearchReturn>{};
    final containsMap = <String, SearchReturn>{};
    for (var dictionary in _dictionaryList) {
      _progressController
          ?.add(MdictProgress('Searching for $term in ${dictionary.name} ...'));
      final mdictSearchResult = await dictionary.search(term);

      for (var key in mdictSearchResult.startsWithSet) {
        final currentValue = startsWithMap[key] ?? SearchReturn(key);
        startsWithMap[key] = currentValue..addDictName(dictionary.name);
      }

      for (var key in mdictSearchResult.containsSet) {
        final currentValue = containsMap[key] ?? SearchReturn(key);
        containsMap[key] = currentValue..addDictName(dictionary.name);
      }
    }
    _progressController?.add(MdictProgress('Finished searching for $term ...'));
    return [...startsWithMap.values, ...containsMap.values];
  }

  Future<List<QueryReturn>> query(String word) async {
    final results = <QueryReturn>[];
    for (var dictionary in _dictionaryList) {
      _progressController
          ?.add(MdictProgress('Querying for $word in ${dictionary.name} ...'));
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
