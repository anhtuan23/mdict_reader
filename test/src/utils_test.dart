import 'dart:io';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:test/test.dart';

void main() {
  group('MdictHelpers', () {
    test('extracts lower-case file names without extensions by default', () {
      expect(
        MdictHelpers.getFileNameFromPath('/dicts/Oxford.MDX'),
        'oxford',
      );
    });

    test('can preserve case when extracting file names without extensions', () {
      expect(
        MdictHelpers.getFileNameFromPath(
          '/dicts/Oxford.MDX',
          toLowerCase: false,
        ),
        'Oxford',
      );
    });

    test('extracts lower-case file names with extensions', () {
      expect(
        MdictHelpers.getFileNameWithExtensionFromPath('/dicts/Oxford.MDX'),
        'oxford.mdx',
      );
    });

    test('returns null when asked to read a null or missing path', () async {
      expect(
        await MdictHelpers.readFileContent(null, const IoMdictFileSystem()),
        isNull,
      );
      expect(
        await MdictHelpers.readFileContent(
          '/path/does/not/exist',
          const IoMdictFileSystem(),
        ),
        isNull,
      );
    });

    test('reads UTF-8 file content', () async {
      final directory = await Directory.systemTemp.createTemp('mdict_utils_');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/style.css');
      await file.writeAsString('body { color: red; }');

      expect(
        await MdictHelpers.readFileContent(
          file.path,
          const IoMdictFileSystem(),
        ),
        'body { color: red; }',
      );
    });
  });

  group('ListExt', () {
    test('adds non-null values and returns the same list', () {
      final values = ['a'];

      final returned = values.addIfNotNull('b');

      expect(identical(returned, values), isTrue);
      expect(values, ['a', 'b']);
    });

    test('ignores null values and returns the same list', () {
      final values = ['a'];

      final returned = values.addIfNotNull(null);

      expect(identical(returned, values), isTrue);
      expect(values, ['a']);
    });
  });
}
