import 'dart:io';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_manager/mdict_manager_models.dart';
import 'package:mdict_reader/src/mdict_reader/mdict_reader_models.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  open.overrideFor(OperatingSystem.windows, openSqliteOnWindows);
  group('standard tests', () {
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

      expect(searchReturnList, isNotEmpty);
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
      const MdictFiles(
        'test/assets/CC-CEDICT/CC-CEDICT.mdx',
        'test/assets/CC-CEDICT/CC-CEDICT.mdd',
        'test/assets/CC-CEDICT/CC-CEDICT.css',
      ),
      const MdictFiles(
        'test/assets/cc_cedict_v2.mdx',
        'test/assets/Sound-zh_CN.mdd',
        null,
      ),
      const MdictFiles(
        'test/assets/mtBab EV v1.0/mtBab EV v1.0.mdx',
        'test/assets/mtBab EV v1.0/mtBab EV v1.0.mdd',
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

  group('index persistency', () {
    final mdictFilesList = [
      const MdictFiles(
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
      await Future.delayed(const Duration(seconds: 3));
      final dbFile = File(_tempDbPath);
      await dbFile.delete();
    });

    test('reuse index make manager start up faster', () async {
      final stopwatch = Stopwatch();
      stopwatch.start();

      mdictManager1 = await MdictManager.create(
        mdictFilesIter: mdictFilesList,
        dbPath: _tempDbPath,
      );
      final firstStartDuration = stopwatch.elapsed;

      // this might fail if the records written in manager1 are not yet committed to the db file
      mdictManager1?.dispose();
      await Future.delayed(const Duration(seconds: 3));

      stopwatch.reset();

      mdictManager2 = await MdictManager.create(
        mdictFilesIter: mdictFilesList,
        dbPath: _tempDbPath,
      );
      final secondStartDuration = stopwatch.elapsed;
      mdictManager2?.dispose();

      printOnFailure('First start duration: $firstStartDuration');
      printOnFailure('Second start duration: $secondStartDuration');

      expect(secondStartDuration, lessThan(firstStartDuration * (1 / 10)));
    });

    test('unused mdict files are discarded from index db', () async {
      mdictManager1 = await MdictManager.create(
        mdictFilesIter: mdictFilesList,
        dbPath: _tempDbPath,
      );

      mdictManager1?.dispose();
      // this might fail if the records written in manager1 are not yet committed to the db file
      await Future.delayed(const Duration(seconds: 2));

      mdictManager2 = await MdictManager.create(
        mdictFilesIter: [],
        dbPath: _tempDbPath,
      );

      mdictManager2?.dispose();
      await Future.delayed(const Duration(seconds: 2));

      final db = sqlite3.open(_tempDbPath);
      final deletedRows = db.select(
        '''
          SELECT *
          FROM ${MdictKey.tableName} 
          WHERE ${MdictKey.filePathColumnName} IN ('test/assets/cc_cedict_v2.mdx', 'test/assets/Sound-zh_CN.mdd')
        ''',
      );

      expect(deletedRows, isEmpty);

      db.dispose();
    });
  });
}
