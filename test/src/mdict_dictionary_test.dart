import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_dictionary.dart';
import 'package:test/test.dart';

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

      expect(searchReturnList.startsWithList, hasLength(1));
      expect(searchReturnList.containsList, hasLength(1));
      expect(searchReturnList.startsWithList.first, equals('勉強'));
      expect(searchReturnList.containsList.first, equals('勉勉強強'));
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
    late MdictDictionary mdictDictionary;

    setUp(
      () async {
        mdictDictionary = await MdictDictionary.create(
          MdictFiles(
            'test/assets/cc_cedict_v2.mdx',
            'test/assets/Sound-zh_CN.mdd',
            null,
          ),
        );
      },
    );

    test('query for sound', () async {
      final data = await mdictDictionary.queryResource('\\犯浑.spx');

      printOnFailure(data.toString());

      expect(data, isNotNull);
      expect(data, isNotEmpty);
    });
  });
}
