import 'package:mdict_reader/mdict_reader.dart';
import 'package:test/test.dart';

void main() {
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
      final searchResultList = await isolatedManager.search(word);
      printOnFailure(searchResultList.toString());
      expect(searchResultList, isNotEmpty);
      expect(searchResultList[0].word, equals(word));
      expect(
        searchResultList[0].dictPathNameMap,
        equals({
          'test/assets/CC-CEDICT/CC-CEDICT.mdx': 'CC-CEDICT',
          'test/assets/jmdict_v2.mdx': 'JMDict',
        }),
      );
    });
    test('query function', () async {
      final queryResultList = await isolatedManager.query(word);
      printOnFailure(queryResultList.toString());
      expect(queryResultList, hasLength(2));
      final firstDictReturn = queryResultList[0];
      expect(firstDictReturn.word, equals(word));
      expect(firstDictReturn.dictName, equals('CC-CEDICT'));
      expect(firstDictReturn.html, isNotEmpty);
      expect(firstDictReturn.css, isNotEmpty);
      final secondDictReturn = queryResultList[1];
      expect(secondDictReturn.word, equals(word));
      expect(secondDictReturn.dictName, equals('JMDict'));
      expect(secondDictReturn.html, isNotEmpty);
      expect(secondDictReturn.css, isEmpty);
    });
    test('reorder function', () async {
      final pathNameMap = await isolatedManager.getPathNameMap();
      expect(
        pathNameMap.values,
        equals(['CC-CEDICT', 'JMDict', 'WordNet 2.0']),
      );
      final newPathNameMap = await isolatedManager.reorder(2, 0);
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
      final newPathNameMap = await isolatedManager.reload(
        newMdictFilesList,
        null,
      );
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
          final progressBroadcast = isolatedManager.progressStream
              .asBroadcastStream();
          expect(
            progressBroadcast,
            emits(const MdictProgressManagerOpenDb()),
          );
        },
      );
    },
  );
  group(
    'isolated manager robustness and concurrency',
    () {
      const word = '勉強';
      late IsolatedManager isolatedManager;
      setUp(() async {
        isolatedManager = await IsolatedManager.init(mdictFilesList, null);
      });

      test(
        'handles multiple concurrent queries and searches without collision',
        () async {
          final futures = <Future<dynamic>>[];
          for (var i = 0; i < 5; i++) {
            futures
              ..add(
                isolatedManager.search(word, null, (e, st) {
                  print('Concurrent search error: $e\n$st');
                }),
              )
              ..add(
                isolatedManager.query(word, null, (e, st) {
                  print('Concurrent query error: $e\n$st');
                }),
              );
          }
          final results = await Future.wait(futures);
          print('Concurrent results count: ${results.length}');
          for (var i = 0; i < results.length; i++) {
            final res = results[i] as List;
            print('Result $i length: ${res.length}');
            expect(res, isNotEmpty);
          }
        },
      );

      test('recovers from worker errors and remains non-blocking', () async {
        Object? capturedError;
        StackTrace? capturedStackTrace;

        final reorderResult = await isolatedManager.reorder(
          999,
          0,
          (err, st) {
            capturedError = err;
            capturedStackTrace = st;
          },
        );
        print('Reorder result: $reorderResult');
        print('Captured error: $capturedError');

        expect(capturedError, isNotNull);
        expect(capturedError, isA<RangeError>());
        expect(capturedStackTrace, isNotNull);

        final searchResultList = await isolatedManager.search(word);
        expect(searchResultList, isNotEmpty);
        expect(searchResultList[0].word, equals(word));
      });
    },
  );
}
