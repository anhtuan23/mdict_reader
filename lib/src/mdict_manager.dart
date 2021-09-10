import 'package:mdict_reader/mdict_reader.dart';

class QueryReturn {
  const QueryReturn(this.word, this.dictName, this.html, this.css);

  final String word;
  final String dictName;
  final String html;
  final String css;
}

class MdictManager {
  const MdictManager._(this._mdictList);

  final List<MdictReader> _mdictList;

  Map<String, String> get pathNameMap =>
      {for (final mdict in _mdictList) mdict.path: mdict.name};

  /// [dictPaths] is a list of [mdxPath, cssPath]
  static Future<MdictManager> create(List<MdictFiles> mdictFilesList) async {
    final mdictList = <MdictReader>[];
    for (var mdictFiles in mdictFilesList) {
      try {
        final mdict = await MdictReader.create(mdictFiles);
        mdictList.add(mdict);
      } catch (e) {
        print('Error with ${mdictFiles.cssPath}: $e');
      }
    }
    return MdictManager._(mdictList);
  }

  Future<Map<String, List<String>>> search(String term) async {
    final startsWithMap = <String, List<String>>{};
    final containsMap = <String, List<String>>{};
    for (var mdict in _mdictList) {
      final mdictSearchResult = await mdict.search(term);

      for (var key in mdictSearchResult.startsWithList) {
        final currentDictList = startsWithMap[key] ?? [];
        startsWithMap[key] = currentDictList..add(mdict.name);
      }

      for (var key in mdictSearchResult.containsList) {
        final currentDictList = containsMap[key] ?? [];
        containsMap[key] = currentDictList..add(mdict.name);
      }
    }
    return startsWithMap..addAll(containsMap);
  }

  Future<List<QueryReturn>> query(String word) async {
    final result = <QueryReturn>[];
    for (var mdict in _mdictList) {
      final htmlCssList = await mdict.query(word);

      if (htmlCssList[0].isNotEmpty) {
        result.add(QueryReturn(
          word,
          mdict.name,
          htmlCssList[0],
          htmlCssList[1],
        ));
      }
    }
    return result;
  }

  MdictManager reOrder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return this;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _mdictList.removeAt(oldIndex);
    _mdictList.insert(newIndex, item);
    return MdictManager._(_mdictList);
  }
}
