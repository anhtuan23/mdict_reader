import 'dart:io';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_manager_models.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  open.overrideFor(OperatingSystem.windows, openSqliteOnWindows);
  group('standard tests', () {
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

    final word = '勉強';

    late MdictManager mdictManager;

    setUp(() async {
      mdictManager = await MdictManager.create(
        mdictFilesIter: mdictFilesList,
        dbPath: null,
      );
    });

    test('search function', () async {
      final searchReturnList = await mdictManager.search(word);

      printOnFailure(searchReturnList.toString());

      expect(searchReturnList, hasLength(20));
      expect(searchReturnList[0].word, equals('勉強'));
      expect(
          searchReturnList[0].dictPathNameMap,
          equals({
            'test/assets/CC-CEDICT/CC-CEDICT.mdx': 'CC-CEDICT',
            'test/assets/jmdict_v2.mdx': 'JMDict'
          }));
    });

    test('query function', () async {
      final queryReturnList = await mdictManager.query(word);

      printOnFailure(queryReturnList.toString());

      expect(queryReturnList, hasLength(2));

      final firstDictReturn = queryReturnList[0];
      expect(firstDictReturn.word, equals('勉強'));
      expect(firstDictReturn.dictName, equals('CC-CEDICT'));
      expect(firstDictReturn.html, isNotEmpty);
      expect(firstDictReturn.css, isNotEmpty);

      final secondDictReturn = queryReturnList[1];
      expect(secondDictReturn.word, equals('勉強'));
      expect(secondDictReturn.dictName, equals('JMDict'));
      expect(secondDictReturn.html, isNotEmpty);
      expect(secondDictReturn.css, isEmpty);
    });

    test('specified query function', () async {
      final queryReturnList = await mdictManager.query(
        word,
        {'test/assets/jmdict_v2.mdx'},
      );

      printOnFailure(queryReturnList.toString());

      expect(
        queryReturnList,
        hasLength(1),
        reason:
            'should only query in dict with mdx path specified in query function',
      );

      final queryReturn = queryReturnList[0];
      expect(queryReturn.word, equals('勉強'));
      expect(queryReturn.dictName, equals('JMDict'));
      expect(queryReturn.html, isNotEmpty);
      expect(queryReturn.css, isEmpty);
    });

    test('reOrder function', () async {
      var pathNameMap = mdictManager.pathNameMap;
      expect(
          pathNameMap.values, equals(['CC-CEDICT', 'JMDict', 'WordNet 2.0']));

      mdictManager = mdictManager.reOrder(2, 0);
      pathNameMap = mdictManager.pathNameMap;
      expect(
          pathNameMap.values, equals(['WordNet 2.0', 'CC-CEDICT', 'JMDict']));
    });
  });

  group('query resource tests', () {
    final mdictFilesList = [
      MdictFiles(
        'test/assets/CC-CEDICT/CC-CEDICT.mdx',
        'test/assets/CC-CEDICT/CC-CEDICT.mdd',
        'test/assets/CC-CEDICT/CC-CEDICT.css',
      ),
      MdictFiles(
        'test/assets/cc_cedict_v2.mdx',
        'test/assets/Sound-zh_CN.mdd',
        null,
      ),
    ];

    late MdictManager mdictManager;

    setUp(() async {
      mdictManager = await MdictManager.create(
        mdictFilesIter: mdictFilesList,
        dbPath: null,
      );
    });

    test('query for sound without mdx path', () async {
      final soundUri = 'sound://犯浑.spx';
      final data = await mdictManager.queryResource(soundUri, null);

      printOnFailure(data.toString());

      expect(data, isNotNull);
      expect(data, isNotEmpty);
    });

    test('query for sound with wrong mdx path', () async {
      final soundUri = 'sound://犯浑.spx';
      final data = await mdictManager.queryResource(
          soundUri, 'test/assets/CC-CEDICT/CC-CEDICT.mdx');

      printOnFailure(data.toString());

      expect(data, isNull);
    });

    test('query for sound with mdxPath', () async {
      final soundUri = 'sound://犯浑.spx';
      final data = await mdictManager.queryResource(
        soundUri,
        'test/assets/cc_cedict_v2.mdx',
      );

      printOnFailure(data.toString());

      expect(data, isNotNull);
      expect(data, isNotEmpty);
    });
  });

  group('reuse index', () {
    final mdictFilesList = [
      MdictFiles(
        'test/assets/CC-CEDICT/CC-CEDICT.mdx',
        'test/assets/CC-CEDICT/CC-CEDICT.mdd',
        'test/assets/CC-CEDICT/CC-CEDICT.css',
      ),
      MdictFiles(
        'test/assets/cc_cedict_v2.mdx',
        'test/assets/Sound-zh_CN.mdd',
        null,
      ),
    ];

    const _tempDbPath = 'test/assets/temp.db';

    MdictManager? mdictManager1;
    MdictManager? mdictManager2;

    tearDown(() async {
      mdictManager1?.dispose();
      mdictManager2?.dispose();
      final dbFile = File(_tempDbPath);
      await dbFile.delete();
    });

    test('query for sound without mdx path', () async {
      final stopwatch = Stopwatch();
      stopwatch.start();

      mdictManager1 = await MdictManager.create(
        mdictFilesIter: mdictFilesList,
        dbPath: _tempDbPath,
      );
      final firstStartDuration = stopwatch.elapsed;

      stopwatch.reset();
      mdictManager2 = await MdictManager.create(
        mdictFilesIter: mdictFilesList,
        dbPath: _tempDbPath,
      );
      final secondStartDuration = stopwatch.elapsed;

      printOnFailure('First start duration: $firstStartDuration');
      printOnFailure('Second start duration: $secondStartDuration');

      expect(secondStartDuration, lessThan(firstStartDuration * (1 / 10)));
    });
  });
}
