import 'package:mdict_reader/mdict_reader.dart';
import 'package:test/test.dart';

void main() {
  group('Normal mdict', () {
    final word = '狗';

    late MdictReader mdictReader;

    setUp(() async {
      mdictReader =
          await MdictReader.create('test/assets/CC-CEDICT/CC-CEDICT.mdx');
    });

    test('search function', () async {
      final searchResult = await mdictReader.search(word);

      printOnFailure(searchResult.toString());

      expect(searchResult.startsWithSet, hasLength(75));
      expect(searchResult.containsSet, hasLength(95));
    });

    test('query function', () async {
      final html = await mdictReader.queryMdx(word);

      printOnFailure(html);

      expect(html, isNotEmpty, reason: 'html content is not empty');
    });
  });
  group('v1 mdict file', () {
    test('should throw error', () async {
      try {
        await MdictReader.create('test/assets/jmdict.mdx');
      } on Exception catch (e) {
        expect(
          e.toString(),
          equals('Exception: This program does not support mdict version 1.x'),
        );
      }
    });
  });

  group('Special query', () {
    late MdictReader mdictReader;

    setUp(() async {
      mdictReader = await MdictReader.create('test/assets/cc_cedict_v2.mdx');
    });

    test('correctly result @@@LINK= in query function', () async {
      final html = await mdictReader.queryMdx('iPhone');

      printOnFailure(html);

      expect(html, isNotEmpty, reason: 'html content is not empty');

      expect(html, isNot(contains('@@@LINK=')));
      expect(html, contains('<font color="red">機 </font>'));
    });
  });

  group('Query resource', () {
    late MdictReader mdictReader;

    setUp(() async {
      mdictReader = await MdictReader.create('test/assets/Sound-zh_CN.mdd');
    });

    test('correctly query sound resource', () async {
      final data = await mdictReader.queryMdd('\\状态.spx');

      printOnFailure(data.toString());

      expect(data, isNotEmpty);
    });
  });
}
