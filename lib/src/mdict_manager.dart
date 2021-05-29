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

  Future<List<String>> query(String word) async {
    final resultList = <String>[];
    for (var mdict in mdictList) {
      final record = await mdict.query(word);
      if (record is String) {
        resultList.add(record);
      }
    }
    return resultList;
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
