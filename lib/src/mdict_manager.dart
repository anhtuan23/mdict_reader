import 'package:mdict_reader/mdict_reader.dart';

class SearchReturn {
  SearchReturn(this.word);

  final String word;
  final List<String> dictNames = [];

  void addDictName(String dictName) => dictNames.add(dictName);

  @override
  String toString() {
    return 'Word: $word\nDict names: $dictNames\n';
  }
}

class QueryReturn {
  const QueryReturn(this.word, this.dictName, this.html, this.css);

  final String word;
  final String dictName;
  final String html;
  final String css;

  @override
  String toString() {
    return 'Word: $word\nDictname: $dictName\nHtml: $html\nCss: $css\n';
  }
}

class MdictManager {
  const MdictManager._(this._mdictList);

  final List<MdictReader> _mdictList;

  Map<String, String> get pathNameMap =>
      {for (final mdict in _mdictList) mdict.path: mdict.name};

  /// [dictPaths] is a list of [mdxPath, cssPath]
  static Future<MdictManager> create(Iterable<MdictFiles> mdictFilesIter) async {
    final mdictList = <MdictReader>[];
    for (var mdictFiles in mdictFilesIter) {
      try {
        final mdict = await MdictReader.create(mdictFiles);
        mdictList.add(mdict);
      } catch (e) {
        print('Error with ${mdictFiles.cssPath}: $e');
      }
    }
    return MdictManager._(mdictList);
  }

  Future<List<SearchReturn>> search(String term) async {
    final startsWithMap = <String, SearchReturn>{};
    final containsMap = <String, SearchReturn>{};
    for (var mdict in _mdictList) {
      final mdictSearchResult = await mdict.search(term);

      for (var key in mdictSearchResult.startsWithList) {
        final currentValue = startsWithMap[key] ?? SearchReturn(key);
        startsWithMap[key] = currentValue..addDictName(mdict.name);
      }

      for (var key in mdictSearchResult.containsList) {
        final currentValue = containsMap[key] ?? SearchReturn(key);
        containsMap[key] = currentValue..addDictName(mdict.name);
      }
    }
    return [...startsWithMap.values, ...containsMap.values];
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
