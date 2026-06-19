import 'dart:typed_data';

import 'package:mdict_reader/src/mdict_dictionary/mdict_dictionary_helper.dart';
import 'package:test/test.dart';

void main() {
  group('MdictDictionaryHelper.inlineImages', () {
    // Beginner-friendly comment:
    // These tests validate the regular expression pattern used to extract
    // <img> tag sources and inline them with base64 data URIs.
    //
    // It verifies double-quoted, single-quoted, and unquoted src paths,
    // trailing attributes, empty attributes, multi-image tags, and strings
    // with no image tags at all.

    test('matches and inlines double-quoted src', () async {
      const html = '<img src="img.png">';
      final result = await MdictDictionaryHelper.inlineImages(
        html: html,
        queryResource: (key) async {
          expect(key, 'img.png');
          return Uint8List.fromList([71, 73, 70]); // dummy bytes
        },
      );
      expect(result, '<img src="data:image/png;base64,R0lG">');
    });

    test('matches and inlines single-quoted src', () async {
      const html = "<img class='lazy' src='img.jpg'>";
      final result = await MdictDictionaryHelper.inlineImages(
        html: html,
        queryResource: (key) async {
          expect(key, 'img.jpg');
          return Uint8List.fromList([1, 2, 3]);
        },
      );
      expect(result, "<img class='lazy' src=\"data:image/jpg;base64,AQID\">");
    });

    test('matches and inlines unquoted src', () async {
      const html = '<IMG src=folder/sub/img.gif>';
      final result = await MdictDictionaryHelper.inlineImages(
        html: html,
        queryResource: (key) async {
          expect(key, r'folder\sub\img.gif');
          return Uint8List.fromList([10, 20]);
        },
      );
      expect(result, '<IMG src="data:image/gif;base64,ChQ=">');
    });

    test('matches and inlines unquoted src with trailing attributes', () async {
      const html = '<img src=img.png width=100 height="50">';
      final result = await MdictDictionaryHelper.inlineImages(
        html: html,
        queryResource: (key) async {
          expect(key, 'img.png');
          return Uint8List.fromList([100]);
        },
      );
      expect(
        result,
        '<img src="data:image/png;base64,ZA==" width=100 height="50">',
      );
    });

    test('handles strings with no image tags', () async {
      const html = '<div>Hello World</div>';
      final result = await MdictDictionaryHelper.inlineImages(
        html: html,
        queryResource: (key) async => null,
      );
      expect(result, html);
    });

    test('inlines multiple image tags in a single string', () async {
      const html = '<img src="1.png"> text <img src=2.png>';
      final result = await MdictDictionaryHelper.inlineImages(
        html: html,
        queryResource: (key) async {
          if (key == '1.png') return Uint8List.fromList([1]);
          if (key == '2.png') return Uint8List.fromList([2]);
          return null;
        },
      );
      expect(
        result,
        '<img src="data:image/png;base64,AQ=="> '
        'text <img src="data:image/png;base64,Ag==">',
      );
    });

    test('leaves tag unchanged if queryResource returns null', () async {
      const html = '<img src="missing.png">';
      final result = await MdictDictionaryHelper.inlineImages(
        html: html,
        queryResource: (key) async => null,
      );
      expect(result, '<img src="missing.png">');
    });
  });
}
