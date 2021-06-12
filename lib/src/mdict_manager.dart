import 'package:mdict_reader/mdict_reader.dart';

class MdictManager {
  const MdictManager._(this._mdictList);

  final List<MdictReader> _mdictList;

  Map<String, String> get pathNameMap =>
      {for (final mdict in _mdictList) mdict.path: mdict.name};

  static Future<MdictManager> create(List<String> pathList) async {
    final mdictList = <MdictReader>[];
    for (var path in pathList) {
      try {
        final mdict = await MdictReader.create(path);
        mdictList.add(mdict);
      } catch (e) {
        print('Error with $path: $e');
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

  Future<Map<String, String>> query(String word) async {
    final result = <String, String>{};
    for (var mdict in _mdictList) {
      final record = await mdict.query(word);
      if (record != null && record is String) {
        final trimmed = record.trim();
        if (trimmed.isNotEmpty) {
          result[mdict.name] = trimmed;
        }
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
