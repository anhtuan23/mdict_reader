import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:html_unescape/html_unescape_small.dart';
import 'package:mdict_reader/src/mdict_dictionary.dart';

/// Need a stable hash to work with IsolatedManager's reload
class MdictFiles extends Equatable {
  const MdictFiles(
    this.mdxPath,
    this.mddPath,
    this.cssPath,
  );

  final String mdxPath;
  final String? mddPath;
  final String? cssPath;

  @override
  List<Object?> get props => [mdxPath, mddPath, cssPath];
}

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
  const MdictManager._(this._dictionaryList);

  final List<MdictDictionary> _dictionaryList;

  Map<String, String> get pathNameMap =>
      {for (final dict in _dictionaryList) dict.mdxPath: dict.name};

  static Future<MdictManager> create(
    Iterable<MdictFiles> mdictFilesIter,
  ) async {
    final dictionaryList = <MdictDictionary>[];
    for (var mdictFiles in mdictFilesIter) {
      try {
        final mdict = await MdictDictionary.create(mdictFiles);
        dictionaryList.add(mdict);
      } catch (e) {
        print('Error with ${mdictFiles.mdxPath}: $e');
      }
    }
    return MdictManager._(dictionaryList);
  }

  Future<List<SearchReturn>> search(String term) async {
    final startsWithMap = <String, SearchReturn>{};
    final containsMap = <String, SearchReturn>{};
    for (var dictionary in _dictionaryList) {
      final mdictSearchResult = await dictionary.search(term);

      for (var key in mdictSearchResult.startsWithList) {
        final currentValue = startsWithMap[key] ?? SearchReturn(key);
        startsWithMap[key] = currentValue..addDictName(dictionary.name);
      }

      for (var key in mdictSearchResult.containsList) {
        final currentValue = containsMap[key] ?? SearchReturn(key);
        containsMap[key] = currentValue..addDictName(dictionary.name);
      }
    }
    return [...startsWithMap.values, ...containsMap.values];
  }

  Future<List<QueryReturn>> query(String word) async {
    final result = <QueryReturn>[];
    for (var dictionary in _dictionaryList) {
      final htmlCssList = await dictionary.queryMdx(word);

      if (htmlCssList[0].isNotEmpty) {
        result.add(QueryReturn(
          word,
          dictionary.name,
          htmlCssList[0],
          htmlCssList[1],
        ));
      }
    }
    return result;
  }

  Future<Uint8List?> queryResource(String resourceUri) async {
    final resourceKey = _parseResourceUri(resourceUri);
    for (var dictionary in _dictionaryList) {
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
    return MdictManager._(_dictionaryList);
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
