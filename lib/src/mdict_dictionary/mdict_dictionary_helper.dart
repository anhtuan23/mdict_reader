import 'dart:convert';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

abstract class MdictDictionaryHelper {
  /// Scans the provided [html] for `img` tags and inlines their resource
  /// bytes from the companion .mdd file using the [queryResource] callback.
  ///
  /// The regular expression pattern splits the `img` tag and its `src`
  /// attribute:
  ///
  /// Group 1: `(<img\s+[^>]*src=\s*)`
  /// - `img` matches the opening of the image tag case-insensitively.
  /// - `\s+` matches one or more whitespace characters separating the tag
  ///   name from attributes.
  /// - `[^>]*` matches any characters that are not closing brackets (so we
  ///   don't search outside the current tag).
  /// - `src=\s*` matches the source attribute name and any following spaces.
  ///
  /// Quoted/Unquoted value matching:
  /// We use a non-capturing group (?: ... ) with three alternatives:
  /// 1. `"([^"]*)"` - Double-quoted URL. Captures URL in Group 2.
  /// 2. `'([^']*)'` - Single-quoted URL. Captures URL in Group 3.
  /// 3. `([^>\s]+)` - Unquoted URL (stops at space or `>`). Captures in Group 4.
  static Future<String> inlineImages({
    required String html,
    required Future<Uint8List?> Function(String resourceKey) queryResource,
  }) async {
    try {
      final regex = RegExp(
        r'''(<img\s+[^>]*src=\s*)(?:"([^"]*)"|'([^']*)'|([^>\s]+))''',
        caseSensitive: false,
      );

      final matches = regex.allMatches(html).toList();
      if (matches.isEmpty) return html;

      final sb = StringBuffer();
      var lastOffset = 0;
      for (final match in matches) {
        // Write the HTML chunk before the current match starts
        sb.write(html.substring(lastOffset, match.start));

        // Extract match groups and provide fallbacks to make them
        // non-nullable:
        // match[1] corresponds to Group 1 (tag start up to 'src=')
        // match[2] corresponds to Group 2 (double-quoted URL)
        // match[3] corresponds to Group 3 (single-quoted URL)
        // match[4] corresponds to Group 4 (unquoted URL)
        final prefix = match[1] ?? '';
        final src = match[2] ?? match[3] ?? match[4] ?? '';

        var replacement = match[0] ?? '';
        var extension = p.extension(src).toLowerCase();
        if (extension.isNotEmpty) {
          extension = extension.replaceFirst('.', '');
          // Fetch the raw bytes from the companion .mdd archive.
          // Replace path separator '/' with '\' to match .mdd keys.
          final intData = await queryResource(src.replaceAll('/', r'\'));
          if (intData != null) {
            final base64Data = base64.encode(intData);
            final dataUri = 'data:image/$extension;base64,$base64Data';
            // Reconstruct the <img> tag with the inline base64 data URI
            // enclosed in double quotes.
            replacement = '$prefix"$dataUri"';
          }
        }
        sb.write(replacement);
        lastOffset = match.end;
      }
      // Write the remaining HTML content
      sb.write(html.substring(lastOffset));
      return sb.toString();
    } on Exception catch (e) {
      print(e);
      return html;
    }
  }
}
