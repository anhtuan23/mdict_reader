import 'dart:io';

import 'package:mdict_reader/mdict_reader.dart';

void main() async {
  // final mdxPaths = [
  //   // 'dict/CC-CEDICT.mdx',
  //   'dict/JaViDic_Ja-Vi.mdx',
  //   // 'dict/OALD_8th.mdx',
  //   'dict/jmdict.mdx',
  // ];
  // final word = '勉強';
  // // final word = '哽咽';

  // final mdictManager = await MdictManager.create(mdxPaths);
  // final records = await mdictManager.query(word);

  // for (var record in records) {
  //   print(record);
  //   print('--------------------------------');
  // }

  // MdictReader example
  // var file = File('keys.txt');
  // var sink = file.openWrite();

  final mdict = await MdictReader.create('dict/OALD_8th.mdd');

  for (var key in mdict.keys()) {
    print(key);
    if (key.contains('css')) {
      var file = File(key);
      await file.writeAsBytes(await mdict.legacyQuery(key));
    }
    // sink.writeln(key);
    // print(key);
  }

  // final record = await mdict.query('coup');
  // print(record);

  // await sink.close();
}
