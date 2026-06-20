import 'package:mdict_reader/mdict_reader.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  Database? db;
  setUp(() {
    db = sqlite3.openInMemory();
    MdictManager.createTables(db: db!, mdictFilesIter: []);
  });
  tearDown(() {
    db?.close();
  });
  group('init', () {
    test('file name with singe quote', () async {
      await MdictReaderInitHelper.init(
        filePath: "test/assets/contains'single quote.mdx",
        db: db!,
        fileSystem: const IoMdictFileSystem(),
      );
    });
  });
  group('Normal mdict', () {
    const word = '狗';
    late MdictReader mdictReader;
    setUp(() async {
      mdictReader = await MdictReaderInitHelper.init(
        filePath: 'test/assets/CC-CEDICT/CC-CEDICT.mdx',
        db: db!,
        fileSystem: const IoMdictFileSystem(),
      );
    });
    test('query function', () async {
      final html = await mdictReader.queryMdx(word);
      printOnFailure(html);
      expect(html, isNotEmpty, reason: 'html content is not empty');
    });
    test('decodes utf-8 definitions without mojibake', () async {
      final html = await mdictReader.queryMdx('中国');

      printOnFailure(html);
      expect(html, contains('China'));
      expect(html, contains('Zhōng'));
      expect(html, isNot(contains('ã')));
      expect(html, isNot(contains('Â')));
      expect(html, isNot(contains('â')));
    });
  });
  group('v1 mdict file', () {
    test('indexes and queries definitions', () async {
      final isSupported = await MdictReaderInitHelper.isSupportedVersion(
        path: 'test/assets/jmdict.mdx',
        fileSystem: const IoMdictFileSystem(),
      );
      expect(isSupported, isTrue);

      final mdictReader = await MdictReaderInitHelper.init(
        filePath: 'test/assets/jmdict.mdx',
        db: db!,
        fileSystem: const IoMdictFileSystem(),
      );
      final html = await mdictReader.queryMdx('勉強');

      printOnFailure(html);
      expect(html, isNotEmpty);
      expect(html, contains('study'));
    });
  });
  group('Special query', () {
    late MdictReader mdictReader;
    setUp(() async {
      mdictReader = await MdictReaderInitHelper.init(
        filePath: 'test/assets/cc_cedict_v2.mdx',
        db: db!,
        fileSystem: const IoMdictFileSystem(),
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
        fileSystem: const IoMdictFileSystem(),
      );
    });
    test('correctly query sound resource', () async {
      final data = await mdictReader.queryMdd(r'\状态.spx');
      printOnFailure(data.toString());
      expect(data, isNotEmpty);
    });
  });
  group('extractCss from mdd', () {
    late MdictReader mdictReader;
    setUp(() async {
      mdictReader = await MdictReaderInitHelper.init(
        filePath: 'test/assets/non_utf8_with_css.mdd',
        db: db!,
        fileSystem: const IoMdictFileSystem(),
      );
    });
    test('able to read css without crashing', () async {
      final css = await mdictReader.extractScriptContent(getCss: true);
      expect(css, isNotEmpty);
    });
  });
  group('extract Js from mdd', () {
    late MdictReader mdictReader;
    setUp(() async {
      mdictReader = await MdictReaderInitHelper.init(
        filePath: 'test/assets/mtBab EV v1.0/mtBab EV v1.0.mdd',
        db: db!,
        fileSystem: const IoMdictFileSystem(),
      );
    });
    test('able to read js without crashing', () async {
      final jsContent = await mdictReader.extractScriptContent(getCss: false);
      expect(jsContent, isNotNull);
      expect(jsContent!.length, 2860);
    });
  });

  group('lifecycle and persistent handle caching', () {
    test(
      'keeps file handle open across queries and closes on dispose',
      () async {
        final mdictReader = await MdictReaderInitHelper.init(
          filePath: 'test/assets/CC-CEDICT/CC-CEDICT.mdx',
          db: db!,
          fileSystem: const IoMdictFileSystem(),
        );

        // Initially, the file handle should be null (lazy loaded on first
        // query).
        expect(mdictReader.fileHandleForTest, isNull);

        // Perform a lookup query to trigger file opening. Use a word that
        // exists in CC-CEDICT.mdx to ensure _readRecord is actually invoked.
        const word = '狗';
        await mdictReader.queryMdx(word);

        // Verify that the file handle is now open and cached
        final handle = mdictReader.fileHandleForTest;
        expect(handle, isNotNull);

        // Perform another lookup query and check that the same handle is reused
        await mdictReader.queryMdx(word);
        expect(mdictReader.fileHandleForTest, same(handle));

        // Call dispose and verify the handle is closed and cleared
        await mdictReader.dispose();
        expect(mdictReader.fileHandleForTest, isNull);
      },
    );
  });
}
