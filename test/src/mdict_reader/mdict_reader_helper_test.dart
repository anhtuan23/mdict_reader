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
}
