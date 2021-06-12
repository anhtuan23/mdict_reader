import 'package:mdict_reader/mdict_reader.dart';

class MdictManager {
  const MdictManager._(this._mdictList);

  final List<MdictReader> _mdictList;

  Map<String, String> get pathNameMap =>
      {for (final mdict in _mdictList) mdict.path: mdict.name};

  /// [dictPaths] is a list of [mdxPath, cssPath]
  static Future<MdictManager> create(List<List<String>> dictPaths) async {
    final mdictList = <MdictReader>[];
    for (var i = 0; i < dictPaths.length; i++) {
      try {
        final mdict =
            await MdictReader.create(dictPaths[i][0], dictPaths[i][1]);
        mdictList.add(mdict);
      } catch (e) {
        print('Error with ${dictPaths[i][0]}: $e');
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

  /// returns {dictName: [html, css]}
  Future<Map<String, List<String>>> query(String word) async {
    final result = <String, List<String>>{};
    for (var mdict in _mdictList) {
      final htmlCssList = await mdict.query(word);

      if (htmlCssList[0].isNotEmpty) {
        result[mdict.name] = htmlCssList;
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
