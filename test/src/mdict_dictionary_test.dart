import 'package:html/parser.dart' show parse;
import 'package:mdict_reader/src/mdict_dictionary/mdict_dictionary.dart';
import 'package:mdict_reader/src/mdict_manager/mdict_manager.dart';
import 'package:mdict_reader/src/mdict_manager/mdict_manager_models.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  open.overrideFor(OperatingSystem.windows, openSqliteOnWindows);
  Database? db;
  setUp(() {
    db = sqlite3.openInMemory();
    MdictManager.createTables(db: db!, mdictFilesIter: []);
  });

  tearDown(() {
    db?.dispose();
  });

  group('standard tests', () {
    const word = '勉強';

    late MdictDictionary mdictDictionary;

    setUp(() async {
      mdictDictionary = await MdictDictionary.create(
        mdictFiles: const MdictFiles(
          'test/assets/CC-CEDICT/CC-CEDICT.mdx',
          'test/assets/CC-CEDICT/CC-CEDICT.mdd',
          'test/assets/CC-CEDICT/CC-CEDICT.css',
        ),
        db: db!,
      );
    });

    test('query function', () async {
      final queryResult = await mdictDictionary.queryMdx(word);

      printOnFailure(queryResult.toString());

      expect(queryResult, hasLength(3));

      expect(queryResult[0], isNotEmpty, reason: 'html content is not empty');
      expect(queryResult[1], isNotEmpty, reason: 'css content is not empty');
    });
  });

  group('query resource tests', () {
    test('query for sound', () async {
      final mdictDictionary = await MdictDictionary.create(
        mdictFiles: const MdictFiles(
          'test/assets/cc_cedict_v2.mdx',
          'test/assets/Sound-zh_CN.mdd',
          null,
        ),
        db: db!,
      );

      final data = await mdictDictionary.queryResource(r'\犯浑.spx');

      printOnFailure(data.toString());

      expect(data, isNotNull);
      expect(data, isNotEmpty);
    });

    test('query result has base64 img src', () async {
      final mdictDictionary = await MdictDictionary.create(
        mdictFiles: const MdictFiles(
          'test/assets/mtBab EV v1.0/mtBab EV v1.0.mdx',
          'test/assets/mtBab EV v1.0/mtBab EV v1.0.mdd',
          null,
        ),
        db: db!,
      );
      final resultList = await mdictDictionary.queryMdx('aardvark');

      printOnFailure(resultList.toString());

      final html = resultList[0];
      final document = parse(html);
      final images = document.getElementsByTagName('img');
      for (final img in images) {
        expect(img.attributes['src'], startsWith('data:image/png;base64,'));
      }
    });
  });

  group('extract css', () {
    test('prioritize css from file over from mdd', () async {
      final mdictDictionary = await MdictDictionary.create(
        mdictFiles: const MdictFiles(
          'test/assets/CC-CEDICT/CC-CEDICT.mdx',
          'test/assets/CC-CEDICT/CC-CEDICT.mdd',
          'test/assets/CC-CEDICT/CC-CEDICT.css',
        ),
        db: db!,
      );
      final resultList = await mdictDictionary.queryMdx('歌词');

      final css = resultList[1];

      printOnFailure(css);

      expect(
        css,
        contains('/* sample content */'),
        reason: 'Must contains css from file',
      );
    });

    test('extract css from from mdd if css file is unavailable', () async {
      final mdictDictionary = await MdictDictionary.create(
        mdictFiles: const MdictFiles(
          'test/assets/CC-CEDICT/CC-CEDICT.mdx',
          'test/assets/CC-CEDICT/CC-CEDICT.mdd',
          '',
        ),
        db: db!,
      );
      final resultList = await mdictDictionary.queryMdx('歌词');

      final css = resultList[1];

      printOnFailure(css);

      expect(css, contains('div.hz{'), reason: 'Must contains css from mdd');
    });

    test('able to read css file in utf-16', () async {
      final mdictDictionary = await MdictDictionary.create(
        mdictFiles: const MdictFiles(
          'test/assets/GrandRobert_Utf16/GrandRobert.mdx',
          'test/assets/GrandRobert_Utf16/GrandRobert.mdd',
          'test/assets/GrandRobert_Utf16/GrandRobert.css',
        ),
        db: db!,
      );
      // Length of css only from css file is 222
      expect(mdictDictionary.cssContent.length, 222);
    });
  });

  group('extract js', () {
    test('able to extract js content from mdd', () async {
      final mdictDictionary = await MdictDictionary.create(
        mdictFiles: const MdictFiles(
          'test/assets/mtBab EV v1.0/mtBab EV v1.0.mdx',
          'test/assets/mtBab EV v1.0/mtBab EV v1.0.mdd',
          null,
        ),
        db: db!,
      );
      expect(mdictDictionary.jsContent.length, 2858);
    });
  });
}
