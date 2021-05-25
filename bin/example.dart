import 'package:mdict_reader/src/mdict_manager.dart';

void main() async {
  final mdxPaths = [
    'dict/CC-CEDICT.mdx',
    'dict/JaViDic_Ja-Vi.mdx',
    'dict/OALD_8th.mdx',
    // 'dict/jmdict.mdx',
  ];
  final word = '勉強';
  // final word = '哽咽';

  final mdictManager = await MdictManager.create(mdxPaths);
  final records = await mdictManager.query(word);

  for (var record in records) {
    print(record);
    print('--------------------------------');
  }

  /// MdictReader example
  // final mdict = await MdictReader.create(mdxPath);
  // final record = await mdict.query(word);
  // print(record);
}
