import 'package:mdict_reader/mdict_reader.dart';

class MdictManager {
  final List<MdictReader> mdictList;

  MdictManager._(this.mdictList);

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

  Map<String, List<String>> search(String term) {
    final result = <String, List<String>>{};
    for (var mdict in mdictList) {
      final keys = mdict.search(term);
      for (var key in keys) {
        final currentDictList = result[key] ?? [];
        result[key] = currentDictList..add(mdict.name);
      }
    }
    return result;
  }

  Future<Map<String, String>> query(String word) async {
    final result = <String, String>{};
    for (var mdict in mdictList) {
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
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = mdictList.removeAt(oldIndex);
    mdictList.insert(newIndex, item);
    return MdictManager._(mdictList);
  }
}
