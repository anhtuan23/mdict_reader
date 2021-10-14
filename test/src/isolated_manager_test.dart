import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_manager/mdict_manager_models.dart';
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
    final word = '勉強';

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
          }));
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

          expect(
            isolatedManager.progressStream,
            emitsInOrder([
              const MdictProgress('Opening index database ...'),
              const MdictProgress('Processing cc-cedict ...'),
              const MdictProgress('Processing cc-cedict mdx ...'),
              const MdictProgress('Building index for cc-cedict ...'),
              const MdictProgress('CC-CEDICT.mdx: Getting index info ...'),
              const MdictProgress('CC-CEDICT.mdx: Building meta table ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 0/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 8191/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 16382/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 24573/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 32764/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 40955/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 49146/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 57337/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 65528/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 73719/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 81910/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 90101/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 98292/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 106483/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 114674/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 122865/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 131056/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 139247/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 147438/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 155629/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 163820/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 172011/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 180202/182173 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdx: Building key table 182173/182173 ...'),
              const MdictProgress('CC-CEDICT.mdx: Building records table ...'),
              const MdictProgress('CC-CEDICT.mdx: Finished building index'),
              const MdictProgress('Getting headers of cc-cedict ...'),
              const MdictProgress('Getting record list of cc-cedict ...'),
              const MdictProgress('Finished creating cc-cedict dictionary'),
              const MdictProgress('Processing cc-cedict mdd ...'),
              const MdictProgress('Building index for cc-cedict ...'),
              const MdictProgress('CC-CEDICT.mdd: Getting index info ...'),
              const MdictProgress('CC-CEDICT.mdd: Building meta table ...'),
              const MdictProgress('CC-CEDICT.mdd: Building key table 0/15 ...'),
              const MdictProgress(
                  'CC-CEDICT.mdd: Building key table 15/15 ...'),
              const MdictProgress('CC-CEDICT.mdd: Building records table ...'),
              const MdictProgress('CC-CEDICT.mdd: Finished building index'),
              const MdictProgress('Getting headers of cc-cedict ...'),
              const MdictProgress('Getting record list of cc-cedict ...'),
              const MdictProgress('Finished creating cc-cedict dictionary'),
              const MdictProgress('Getting css style of cc-cedict ...'),
              const MdictProgress('Finished creating cc-cedict dictionary ...'),
              const MdictProgress('Processing jmdict_v2 ...'),
              const MdictProgress('Processing jmdict_v2 mdx ...'),
              const MdictProgress('Building index for jmdict_v2 ...'),
              const MdictProgress('jmdict_v2.mdx: Getting index info ...'),
              const MdictProgress('jmdict_v2.mdx: Building meta table ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 0/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 8191/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 16382/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 24573/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 32764/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 40955/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 49146/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 57337/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 65528/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 73719/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 81910/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 90101/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 98292/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 106483/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 114674/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 122865/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 131056/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 139247/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 147438/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 155629/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 163820/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 172011/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 180202/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 188393/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 196584/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 204775/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 212966/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 221157/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 229348/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 237539/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 245730/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 253921/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 262112/267322 ...'),
              const MdictProgress(
                  'jmdict_v2.mdx: Building key table 267322/267322 ...'),
              const MdictProgress('jmdict_v2.mdx: Building records table ...'),
              const MdictProgress('jmdict_v2.mdx: Finished building index'),
              const MdictProgress('Getting headers of jmdict_v2 ...'),
              const MdictProgress('Getting record list of jmdict_v2 ...'),
              const MdictProgress('Finished creating jmdict_v2 dictionary'),
              const MdictProgress('Getting css style of jmdict_v2 ...'),
              const MdictProgress('Finished creating jmdict_v2 dictionary ...'),
              const MdictProgress('Processing wordnet20_v2 ...'),
              const MdictProgress('Processing wordnet20_v2 mdx ...'),
              const MdictProgress('Building index for wordnet20_v2 ...'),
              const MdictProgress('wordnet20_v2.mdx: Getting index info ...'),
              const MdictProgress('wordnet20_v2.mdx: Building meta table ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 0/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 8191/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 16382/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 24573/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 32764/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 40955/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 49146/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 57337/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 65528/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 73719/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 81910/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 90101/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 98292/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 106483/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 114674/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 122865/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 131056/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 139247/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building key table 144301/144301 ...'),
              const MdictProgress(
                  'wordnet20_v2.mdx: Building records table ...'),
              const MdictProgress('wordnet20_v2.mdx: Finished building index'),
              const MdictProgress('Getting headers of wordnet20_v2 ...'),
              const MdictProgress('Getting record list of wordnet20_v2 ...'),
              const MdictProgress('Finished creating wordnet20_v2 dictionary'),
              const MdictProgress('Getting css style of wordnet20_v2 ...'),
              const MdictProgress(
                  'Finished creating wordnet20_v2 dictionary ...'),
              const MdictProgress('Querying for 勉強 in CC-CEDICT ...'),
              const MdictProgress('Querying for 勉強 in JMDict ...'),
              const MdictProgress('Querying for 勉強 in WordNet 2.0 ...'),
              const MdictProgress('Finished querying for 勉強 ...'),
            ]),
          );
        },
      );
    },
  );
}
