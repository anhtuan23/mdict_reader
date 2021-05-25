import 'package:mdict_reader/mdict_reader.dart';

class MdictManager {
  final List<MdictReader> mdictList;

  MdictManager._(this.mdictList);

  static Future<MdictManager> create(List<String> pathList) async {
    final mdictList = <MdictReader>[];
    for (var path in pathList) {
      final mdict = await MdictReader.create(path);
      mdictList.add(mdict);
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
}
