import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_dictionary.dart';
import 'package:test/test.dart';
import 'package:html/parser.dart' show parse;

void main() {
  group('standard tests', () {
    final word = '勉強';

    late MdictDictionary mdictDictionary;

    setUp(() async {
      mdictDictionary = await MdictDictionary.create(
        MdictFiles(
          'test/assets/CC-CEDICT/CC-CEDICT.mdx',
          'test/assets/CC-CEDICT/CC-CEDICT.mdd',
          'test/assets/CC-CEDICT/CC-CEDICT.css',
        ),
      );
    });

    test('search function', () async {
      final searchReturnList = await mdictDictionary.search(word);

      printOnFailure(searchReturnList.toString());

      expect(searchReturnList.startsWithSet, hasLength(1));
      expect(searchReturnList.containsSet, hasLength(1));
      expect(searchReturnList.startsWithSet.first, equals('勉強'));
      expect(searchReturnList.containsSet.first, equals('勉勉強強'));
    });

    test('query function', () async {
      final queryResult = await mdictDictionary.queryMdx(word);

      printOnFailure(queryResult.toString());

      expect(queryResult, hasLength(2));

      expect(queryResult, hasLength(2));
      expect(queryResult[0], isNotEmpty, reason: 'html content is not empty');
      expect(queryResult[1], isNotEmpty, reason: 'css content is not empty');
    });
  });

  group('query resource tests', () {
    test('query for sound', () async {
      final mdictDictionary = await MdictDictionary.create(
        MdictFiles(
          'test/assets/cc_cedict_v2.mdx',
          'test/assets/Sound-zh_CN.mdd',
          null,
        ),
      );

      final data = await mdictDictionary.queryResource('\\犯浑.spx');

      printOnFailure(data.toString());

      expect(data, isNotNull);
      expect(data, isNotEmpty);
    });

    test('query result has base64 img src', () async {
      final mdictDictionary = await MdictDictionary.create(
        MdictFiles(
          'test/assets/mtBab EV v1.0/mtBab EV v1.0.mdx',
          'test/assets/mtBab EV v1.0/mtBab EV v1.0.mdd',
          null,
        ),
      );
      final resultList = await mdictDictionary.queryMdx('aardvark');

      printOnFailure(resultList.toString());

      final html = resultList[0];
      final document = parse(html);
      final images = document.getElementsByTagName('img');
      for (var img in images) {
        expect(img.attributes['src'], startsWith('data:image/png;base64,'));
      }
    });

    test('css string has both content in css file and mdd css entry', () async {
      final mdictDictionary = await MdictDictionary.create(
        MdictFiles(
          'test/assets/CC-CEDICT/CC-CEDICT.mdx',
          'test/assets/CC-CEDICT/CC-CEDICT.mdd',
          'test/assets/CC-CEDICT/CC-CEDICT.css',
        ),
      );
      final resultList = await mdictDictionary.queryMdx('歌词');

      final css = resultList[1];

      printOnFailure(css);

      expect(css, contains('/* sample content */'),
          reason: 'Must contains css from file');
      expect(css, contains('div.hz{'), reason: 'Must contains css from mdd');
    });
  });
}
