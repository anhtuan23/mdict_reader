import 'package:mdict_reader/mdict_reader.dart';
import 'package:test/test.dart';

void main() {
  group('cssUrlExtractor', () {
    test('able to get all matches', () {
      // arrange
      const input = '''
          @import url(googleapis.css);
          background-size: 90% 90%;
          .ox3ksymsub_a2 {
            background-image: url('data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGl');
          }
          div.collapse .unbox .box_title:before, div.collapse pnc.heading:before {
            background-image: url(icon-plus-minus-orange.png);
          }
      ''';
      // act
      final matches = MdictReaderHelper.cssUrlExtractor(input).toList();
      // assert
      expect(matches.length, 2);
      expect(matches[0].group(0), 'googleapis.css');
      expect(matches[1].group(0), 'icon-plus-minus-orange.png');
    });
  });

  group('parseHeaderForTesting', () {
    // Beginner-friendly comment:
    // These tests validate the RegExp used to parse XML-like header
    // attributes from dictionary files. It checks different quote types,
    // spaces, casing, and empty attributes.

    test('handles standard double quotes and mixed spaces', () {
      const header = '  <Dictionary Title="My Dict" Version="2.0"  >';
      final result = MdictReaderHelper.parseHeaderForTesting(header);
      expect(result['title'], 'My Dict');
      expect(result['version'], '2.0');
    });

    test('handles single quotes and different casing', () {
      const header = "<Dictionary ENCRYPTED='2' title='Title' >";
      final result = MdictReaderHelper.parseHeaderForTesting(header);
      expect(result['encrypted'], '2');
      expect(result['title'], 'Title');
    });

    test('handles empty attributes', () {
      const header = '<Dictionary empty="" another=\'\' >';
      final result = MdictReaderHelper.parseHeaderForTesting(header);
      expect(result['empty'], '');
      expect(result['another'], '');
    });

    test('handles multi-line description text with special characters', () {
      const header = '''
        <Dictionary Description="Line 1\nLine 2\n# Tag\nSpecial: &lt;br&gt;" Title="Test">
      ''';
      final result = MdictReaderHelper.parseHeaderForTesting(header);
      expect(
        result['description'],
        'Line 1\nLine 2\n# Tag\nSpecial: &lt;br&gt;',
      );
      expect(result['title'], 'Test');
    });
  });

  group('imageTagRegex', () {
    // Beginner-friendly comment:
    // These tests validate the regular expression pattern used to extract
    // <img> tag sources and inline them with base64 data URIs.
    //
    // The RegExp is:
    // r'''(<img\s+[^>]*src=\s*)(?:"([^"]*)"|'([^']*)'|([^>\s]+))''',
    //
    // - Group 1 captures the opening of the image tag up to 'src='.
    // - Non-capturing group matches three alternatives for the URL:
    //   - Group 2 (double-quoted): captures inside "..."
    //   - Group 3 (single-quoted): captures inside '...'
    //   - Group 4 (unquoted): captures characters until whitespace or '>'
    final regex = RegExp(
      r'''(<img\s+[^>]*src=\s*)(?:"([^"]*)"|'([^']*)'|([^>\s]+))''',
      caseSensitive: false,
    );

    // Helper method matching the replacement logic in MdictDictionary
    String inlineImages(String html, Map<String, String> resources) {
      final matches = regex.allMatches(html).toList();
      if (matches.isEmpty) return html;

      final sb = StringBuffer();
      var lastOffset = 0;
      for (final match in matches) {
        sb.write(html.substring(lastOffset, match.start));

        final prefix = match[1] ?? '';
        final src = match[2] ?? match[3] ?? match[4] ?? '';

        var replacement = match[0] ?? '';
        if (resources.containsKey(src)) {
          replacement = '$prefix"${resources[src]}"';
        }
        sb.write(replacement);
        lastOffset = match.end;
      }
      sb.write(html.substring(lastOffset));
      return sb.toString();
    }

    test('matches and inlines double-quoted src', () {
      const html = '<img src="img.png">';
      final result = inlineImages(html, {'img.png': 'data:base64_1'});
      expect(result, '<img src="data:base64_1">');
    });

    test('matches and inlines single-quoted src', () {
      const html = "<img class='lazy' src='img.jpg'>";
      final result = inlineImages(html, {'img.jpg': 'data:base64_2'});
      expect(result, "<img class='lazy' src=\"data:base64_2\">");
    });

    test('matches and inlines unquoted src', () {
      const html = '<IMG src=folder/sub/img.gif>';
      final result = inlineImages(
        html,
        {'folder/sub/img.gif': 'data:base64_3'},
      );
      expect(result, '<IMG src="data:base64_3">');
    });

    test('matches and inlines unquoted src with trailing attributes', () {
      const html = '<img src=img.png width=100 height="50">';
      final result = inlineImages(html, {'img.png': 'data:base64_4'});
      expect(result, '<img src="data:base64_4" width=100 height="50">');
    });

    test('correctly handles strings with no image tags', () {
      const html = '<div>Hello World</div>';
      final result = inlineImages(html, {});
      expect(result, html);
    });

    test('inlines multiple image tags in a single string', () {
      const html = '<img src="1.png"> text <img src=2.png>';
      final result = inlineImages(html, {
        '1.png': 'data:1',
        '2.png': 'data:2',
      });
      expect(result, '<img src="data:1"> text <img src="data:2">');
    });
  });
}
