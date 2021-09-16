import 'dart:typed_data';

import 'package:html_unescape/html_unescape_small.dart';
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
  const MdictManager._(this._mdxList, this._mddList);

  final List<MdictReader> _mdxList;
  final List<MdictReader> _mddList;

  Map<String, String> get pathNameMap =>
      {for (final mdict in _mdxList) mdict.path: mdict.name};

  static Future<MdictManager> create(
      Iterable<MdictFiles> mdictFilesIter) async {
    final mdxList = <MdictReader>[];
    final mddList = <MdictReader>[];
    for (var mdictFiles in mdictFilesIter) {
      try {
        final mdict = await MdictReader.create(mdictFiles);
        if (mdictFiles.mdictFilePath.endsWith('.mdx')) {
          mdxList.add(mdict);
        } else {
          mddList.add(mdict);
        }
      } catch (e) {
        print('Error with ${mdictFiles.cssPath}: $e');
      }
    }
    return MdictManager._(mdxList, mddList);
  }

  Future<List<SearchReturn>> search(String term) async {
    final startsWithMap = <String, SearchReturn>{};
    final containsMap = <String, SearchReturn>{};
    for (var mdict in _mdxList) {
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
    for (var mdict in _mdxList) {
      final htmlCssList = await mdict.queryMdx(word);

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

  Future<Uint8List?> queryResource(String resourceUri) async {
    final resourceKey = _parseResourceUri(resourceUri);
    for (var mdict in _mddList) {
      final data = await mdict.queryMdd(resourceKey);
      if (data != null) return data;
    }
  }

  MdictManager reOrder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return this;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _mdxList.removeAt(oldIndex);
    _mdxList.insert(newIndex, item);
    return MdictManager._(_mdxList, _mddList);
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
