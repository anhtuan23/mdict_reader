import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_manager_models.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  open.overrideFor(OperatingSystem.windows, openSqliteOnWindows);
  final mdictFilesList = [
    MdictFiles(
      'test/assets/CC-CEDICT/CC-CEDICT.mdx',
      'test/assets/CC-CEDICT/CC-CEDICT.mdd',
      'test/assets/CC-CEDICT/CC-CEDICT.css',
    ),
    MdictFiles(
      'test/assets/jmdict_v2.mdx',
      null,
      null,
    ),
    MdictFiles(
      'test/assets/wordnet20_v2.mdx',
      null,
      null,
    ),
  ];

  group('functions test', () {
    final word = '勉強';

    late IsolatedManager isolatedManager;

    setUp(() async {
      isolatedManager = await IsolatedManager.init(mdictFilesList, null);
    });

    test('search function', () async {
      final searchReturnList = await isolatedManager.search(word);

      printOnFailure(searchReturnList.toString());

      expect(searchReturnList, hasLength(20));
      expect(searchReturnList[0].word, equals(word));
      expect(searchReturnList[0].dictNames, equals(['CC-CEDICT', 'JMDict']));
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
          pathNameMap.values, equals(['CC-CEDICT', 'JMDict', 'WordNet 2.0']));

      final newPathNameMap = await isolatedManager.reOrder(2, 0);
      expect(newPathNameMap.values,
          equals(['WordNet 2.0', 'CC-CEDICT', 'JMDict']));
    });

    test('reload function', () async {
      final pathNameMap = await isolatedManager.getPathNameMap();
      expect(
          pathNameMap.values, equals(['CC-CEDICT', 'JMDict', 'WordNet 2.0']));

      final newMdictFilesList = [
        MdictFiles(
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

          expect(
            isolatedManager.progressStream,
            emitsInOrder([
              MdictProgress('Opening index database ...'),
              MdictProgress('Getting table names ...'),
              MdictProgress('Processing cc-cedict ...'),
              MdictProgress('Processing cc-cedict mdx ...'),
              MdictProgress('Building index for cc-cedict ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Droping test/assets/CC-CEDICT/CC-CEDICT.mdx_meta table ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Droping test/assets/CC-CEDICT/CC-CEDICT.mdx_keys table ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Droping test/assets/CC-CEDICT/CC-CEDICT.mdx_records table ...'),
              MdictProgress('CC-CEDICT.mdx: Getting index info ...'),
              MdictProgress('CC-CEDICT.mdx: Building meta table ...'),
              MdictProgress('CC-CEDICT.mdx: Building key table 0/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 10000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 20000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 30000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 40000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 50000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 60000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 70000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 80000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 90000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 100000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 110000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 120000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 130000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 140000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 150000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 160000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 170000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 180000/182173 ...'),
              MdictProgress(
                  'CC-CEDICT.mdx: Building key table 182173/182173 ...'),
              MdictProgress('CC-CEDICT.mdx: Building records table ...'),
              MdictProgress('CC-CEDICT.mdx: Finished building index'),
              MdictProgress('Getting headers of cc-cedict ...'),
              MdictProgress('Getting record list of cc-cedict ...'),
              MdictProgress('Finished creating cc-cedict dictionary'),
              MdictProgress('Processing cc-cedict mdd ...'),
              MdictProgress('Building index for cc-cedict ...'),
              MdictProgress(
                  'CC-CEDICT.mdd: Droping test/assets/CC-CEDICT/CC-CEDICT.mdd_meta table ...'),
              MdictProgress(
                  'CC-CEDICT.mdd: Droping test/assets/CC-CEDICT/CC-CEDICT.mdd_keys table ...'),
              MdictProgress(
                  'CC-CEDICT.mdd: Droping test/assets/CC-CEDICT/CC-CEDICT.mdd_records table ...'),
              MdictProgress('CC-CEDICT.mdd: Getting index info ...'),
              MdictProgress('CC-CEDICT.mdd: Building meta table ...'),
              MdictProgress('CC-CEDICT.mdd: Building key table 0/15 ...'),
              MdictProgress('CC-CEDICT.mdd: Building key table 15/15 ...'),
              MdictProgress('CC-CEDICT.mdd: Building records table ...'),
              MdictProgress('CC-CEDICT.mdd: Finished building index'),
              MdictProgress('Getting headers of cc-cedict ...'),
              MdictProgress('Getting record list of cc-cedict ...'),
              MdictProgress('Finished creating cc-cedict dictionary'),
              MdictProgress('Gettiing css style of cc-cedict ...'),
              MdictProgress('Finished creating cc-cedict dictionary ...'),
              MdictProgress('Processing jmdict_v2 ...'),
              MdictProgress('Processing jmdict_v2 mdx ...'),
              MdictProgress('Building index for jmdict_v2 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Droping test/assets/jmdict_v2.mdx_meta table ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Droping test/assets/jmdict_v2.mdx_keys table ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Droping test/assets/jmdict_v2.mdx_records table ...'),
              MdictProgress('jmdict_v2.mdx: Getting index info ...'),
              MdictProgress('jmdict_v2.mdx: Building meta table ...'),
              MdictProgress('jmdict_v2.mdx: Building key table 0/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 10000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 20000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 30000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 40000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 50000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 60000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 70000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 80000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 90000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 100000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 110000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 120000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 130000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 140000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 150000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 160000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 170000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 180000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 190000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 200000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 210000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 220000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 230000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 240000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 250000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 260000/267322 ...'),
              MdictProgress(
                  'jmdict_v2.mdx: Building key table 267322/267322 ...'),
              MdictProgress('jmdict_v2.mdx: Building records table ...'),
              MdictProgress('jmdict_v2.mdx: Finished building index'),
              MdictProgress('Getting headers of jmdict_v2 ...'),
              MdictProgress('Getting record list of jmdict_v2 ...'),
              MdictProgress('Finished creating jmdict_v2 dictionary'),
              MdictProgress('Gettiing css style of jmdict_v2 ...'),
              MdictProgress('Finished creating jmdict_v2 dictionary ...'),
              MdictProgress('Processing wordnet20_v2 ...'),
              MdictProgress('Processing wordnet20_v2 mdx ...'),
              MdictProgress('Building index for wordnet20_v2 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Droping test/assets/wordnet20_v2.mdx_meta table ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Droping test/assets/wordnet20_v2.mdx_keys table ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Droping test/assets/wordnet20_v2.mdx_records table ...'),
              MdictProgress('wordnet20_v2.mdx: Getting index info ...'),
              MdictProgress('wordnet20_v2.mdx: Building meta table ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 0/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 10000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 20000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 30000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 40000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 50000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 60000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 70000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 80000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 90000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 100000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 110000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 120000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 130000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 140000/144301 ...'),
              MdictProgress(
                  'wordnet20_v2.mdx: Building key table 144301/144301 ...'),
              MdictProgress('wordnet20_v2.mdx: Building records table ...'),
              MdictProgress('wordnet20_v2.mdx: Finished building index'),
              MdictProgress('Getting headers of wordnet20_v2 ...'),
              MdictProgress('Getting record list of wordnet20_v2 ...'),
              MdictProgress('Finished creating wordnet20_v2 dictionary'),
              MdictProgress('Gettiing css style of wordnet20_v2 ...'),
              MdictProgress('Finished creating wordnet20_v2 dictionary ...'),
              MdictProgress('Searching for 勉強 in CC-CEDICT ...'),
              MdictProgress('Searching for 勉強 in JMDict ...'),
              MdictProgress('Searching for 勉強 in WordNet 2.0 ...'),
              MdictProgress('Finished searching for 勉強 ...'),
              MdictProgress('Querying for 勉強 in CC-CEDICT ...'),
              MdictProgress('Querying for 勉強 in JMDict ...'),
              MdictProgress('Querying for 勉強 in WordNet 2.0 ...'),
              MdictProgress('Finished querying for 勉強 ...'),
            ]),
          );
        },
      );
    },
  );
}
