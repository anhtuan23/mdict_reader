import 'package:mdict_reader/mdict_reader.dart';
import 'package:test/test.dart';

void main() {
  group('Normal mdict', () {
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
      final queryResult = await mdictReader.queryMdx(word);

      printOnFailure(queryResult.toString());

      expect(queryResult, hasLength(2));
      expect(queryResult[0], isNotEmpty, reason: 'html content is not empty');
      expect(queryResult[1], isNotEmpty, reason: 'css content is not empty');
    });
  });
  group('v1 mdict file', () {
    final mdictFiles = MdictFiles(
      'test/assets/jmdict.mdx',
    );

    test('should throw error', () async {
      try {
        await MdictReader.create(mdictFiles);
      } on Exception catch (e) {
        expect(
          e.toString(),
          equals('Exception: This program does not support mdict version 1.x'),
        );
      }
    });
  });

  group('Special query', () {
    final mdictFiles = MdictFiles(
      'test/assets/cc_cedict_v2.mdx',
    );

    late MdictReader mdictReader;

    setUp(() async {
      mdictReader = await MdictReader.create(mdictFiles);
    });

    test('correctly result @@@LINK= in query function', () async {
      final queryResult = await mdictReader.queryMdx('iPhone');

      printOnFailure(queryResult.toString());

      expect(queryResult, hasLength(2));

      final htmlString = queryResult[0];
      expect(htmlString, isNotEmpty, reason: 'html content is not empty');

      expect(htmlString, isNot(contains('@@@LINK=')));
      expect(htmlString, contains('<font color="red">機 </font>'));
    });
  });

  group('Query resource', () {
    final mdictFiles = MdictFiles('test/assets/Sound-zh_CN.mdd');

    late MdictReader mdictReader;

    setUp(() async {
      mdictReader = await MdictReader.create(mdictFiles);
    });

    test('correctly query sound resource', () async {
      final data = await mdictReader.queryMdd('\\状态.spx');

      printOnFailure(data.toString());

      expect(data, isNotEmpty);
    });
  });
}
