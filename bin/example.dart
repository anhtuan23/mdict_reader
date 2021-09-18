import 'package:mdict_reader/mdict_reader.dart';

void main() async {
  /// *** MdictManager ***
  // final mdxPaths = [
  //   // 'dict/CC-CEDICT.mdx',
  //   MdictFiles('dict/JaViDic_Ja-Vi.mdx'),
  //   // 'dict/OALD_8th.mdx',
  //   // 'dict/jmdict.mdx',
  // ];
  // final word = '勉強';
  // // final word = '哽咽';

  // final mdictManager = await MdictManager.create(mdxPaths);
  // final queryReturnList = await mdictManager.query(word);

  // for (var queryReturn in queryReturnList) {
  //   print(queryReturn.html);
  //   print('--------------------------------');
  // }

  /// *** MdictReader ***
  final mdictReader = await MdictReader.create('./dict/mtBab EV v1.0/mtBab EV v1.0.mdd', null);

  // final result = await mdictReader.queryMdx('aardvark');
  // print(result[0]);

  for (var key in mdictReader.keys()) {
    print(key);
  }
}
