
import 'package:mdict_reader/mdict_reader.dart';

void main() async {
  final mdxPaths = [
    // 'dict/CC-CEDICT.mdx',
    MdictFiles('dict/JaViDic_Ja-Vi.mdx'),
    // 'dict/OALD_8th.mdx',
    // 'dict/jmdict.mdx',
  ];
  final word = '勉強';
  // final word = '哽咽';

  final mdictManager = await MdictManager.create(mdxPaths);
  final queryReturnList = await mdictManager.query(word);

  for (var queryReturn in queryReturnList) {
    print(queryReturn.html);
    print('--------------------------------');
  }

  // MdictReader example
  // var file = File('keys.txt');
  // var sink = file.openWrite();

  // final mdict = await MdictReader.create('./dict/OALD9.mdx');
  // for (var key in mdict.keys()) {
  //   print(key);
  //   if (key.contains('css')) {
  //     var file = File(key);
  //     await file.writeAsBytes(await mdict.legacyQuery(key));
  //   }
  //   // sink.writeln(key);
  //   // print(key);
  // }

  // final record = await mdict.query('coup');
  // print(record);

  // await sink.close();
}
