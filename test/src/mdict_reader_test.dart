import 'package:mdict_reader/mdict_reader.dart';
import 'package:test/test.dart';

void main() {
  final mdictFiles = MdictFiles(
    'test/assets/CC-CEDICT/CC-CEDICT.mdx',
    'test/assets/CC-CEDICT/CC-CEDICT.css',
  );

  final word = '狗';

  late MdictReader mdictReader;

  setUp(() async {
    mdictReader = await MdictReader.create(mdictFiles);
  });

  test('search function', () async {
    final searchResult = await mdictReader.search(word);

    printOnFailure(searchResult.toString());

    expect(searchResult.startsWithList, hasLength(75));
    expect(searchResult.containsList, hasLength(95));
  });

  test('query function', () async {
    final queryResult = await mdictReader.query(word);

    printOnFailure(queryResult.toString());

    expect(queryResult, hasLength(2));
    expect(queryResult[0], isNotEmpty, reason: 'html content is not empty');
    expect(queryResult[1], isNotEmpty, reason: 'css content is not empty');
  });
}
