import 'package:mdict_reader/mdict_reader.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  open.overrideFor(OperatingSystem.windows, openSqliteOnWindows);
  final mdictFilesList = [
    const MdictFiles(
      'test/assets/CC-CEDICT/CC-CEDICT.mdx',
      'test/assets/CC-CEDICT/CC-CEDICT.mdd',
      'test/assets/CC-CEDICT/CC-CEDICT.css',
    ),
    const MdictFiles(
      'test/assets/jmdict_v2.mdx',
      null,
      null,
    ),
    const MdictFiles(
      'test/assets/wordnet20_v2.mdx',
      null,
      null,
    ),
  ];

  group('functions test', () {
    const word = '勉強';

    late IsolatedManager isolatedManager;

    setUp(() async {
      isolatedManager = await IsolatedManager.init(mdictFilesList, null);
    });

    test('search function', () async {
      final searchReturnList = await isolatedManager.search(word);

      printOnFailure(searchReturnList.toString());

      expect(searchReturnList, isNotEmpty);
      expect(searchReturnList[0].word, equals(word));
      expect(
        searchReturnList[0].dictPathNameMap,
        equals({
          'test/assets/CC-CEDICT/CC-CEDICT.mdx': 'CC-CEDICT',
          'test/assets/jmdict_v2.mdx': 'JMDict'
        }),
      );
    });

    test('query function', () async {
      final queryReturnList = await isolatedManager.query(word);

      printOnFailure(queryReturnList.toString());

      expect(queryReturnList, hasLength(2));

      final firstDictReturn = queryReturnList[0];
      expect(firstDictReturn.word, equals(word));
      expect(firstDictReturn.dictName, equals('CC-CEDICT'));
      expect(firstDictReturn.html, isNotEmpty);
      expect(firstDictReturn.css, isNotEmpty);

      final secondDictReturn = queryReturnList[1];
      expect(secondDictReturn.word, equals(word));
      expect(secondDictReturn.dictName, equals('JMDict'));
      expect(secondDictReturn.html, isNotEmpty);
      expect(secondDictReturn.css, isEmpty);
    });

    test('reOrder function', () async {
      final pathNameMap = await isolatedManager.getPathNameMap();
      expect(
        pathNameMap.values,
        equals(['CC-CEDICT', 'JMDict', 'WordNet 2.0']),
      );

      final newPathNameMap = await isolatedManager.reOrder(2, 0);
      expect(
        newPathNameMap.values,
        equals(['WordNet 2.0', 'CC-CEDICT', 'JMDict']),
      );
    });

    test('reload function', () async {
      final pathNameMap = await isolatedManager.getPathNameMap();
      expect(
        pathNameMap.values,
        equals(['CC-CEDICT', 'JMDict', 'WordNet 2.0']),
      );

      final newMdictFilesList = [
        const MdictFiles(
          'test/assets/CC-CEDICT/CC-CEDICT.mdx',
          'test/assets/CC-CEDICT/CC-CEDICT.mdd',
          'test/assets/CC-CEDICT/CC-CEDICT.css',
        ),
      ];

      final newPathNameMap =
          await isolatedManager.reload(newMdictFilesList, null);
      expect(newPathNameMap.values, equals(['CC-CEDICT']));
    });
  });

  group(
    'progress stream test',
    () {
      late IsolatedManager isolatedManager;

      setUp(() async {
        isolatedManager = await IsolatedManager.init(mdictFilesList, null);
      });

      test(
        'progress stream update correctly',
        () async {
          await isolatedManager.search('勉強');
          await isolatedManager.query('勉強');

          final progressBroadcast =
              isolatedManager.progressStream.asBroadcastStream();

          expect(
            progressBroadcast,
            emits(const MdictProgress.mdictManagerOpenDb()),
          );
        },
      );
    },
  );
}
