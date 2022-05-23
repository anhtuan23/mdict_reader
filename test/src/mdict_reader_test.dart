import 'package:mdict_reader/mdict_reader.dart';
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

  group('Normal mdict', () {
    const word = '狗';

    late MdictReader mdictReader;

    setUp(() async {
      mdictReader = await MdictReaderInitHelper.init(
        filePath: 'test/assets/CC-CEDICT/CC-CEDICT.mdx',
        db: db!,
      );
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
        await MdictReaderInitHelper.init(
          filePath: 'test/assets/jmdict.mdx',
          db: db!,
        );
      } on Exception catch (e) {
        expect(
          e.toString(),
          startsWith('Exception: This program does not support mdict version'),
        );
      }
    });
  });

  group('Special query', () {
    late MdictReader mdictReader;

    setUp(() async {
      mdictReader = await MdictReaderInitHelper.init(
        filePath: 'test/assets/cc_cedict_v2.mdx',
        db: db!,
      );
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
      mdictReader = await MdictReaderInitHelper.init(
        filePath: 'test/assets/Sound-zh_CN.mdd',
        db: db!,
      );
    });

    test('correctly query sound resource', () async {
      final data = await mdictReader.queryMdd(r'\状态.spx');

      printOnFailure(data.toString());

      expect(data, isNotEmpty);
    });
  });
}
