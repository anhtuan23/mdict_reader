import 'package:mdict_reader/mdict_reader.dart';

void main() async {
  final mdxPath = 'dict/CC-CEDICT.mdx';
  final word = '了';
  // final word = '哽咽';

  final mdict = MdictReader(mdxPath);

  final record = await mdict.query(word);

  print(record);
}
