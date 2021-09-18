import 'dart:convert';
import 'dart:typed_data';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_reader.dart';
import 'package:path/path.dart' as p;
import 'package:html/parser.dart' show parse;

class MdictDictionary {
  MdictDictionary._({
    required this.name,
    required this.mdxReader,
    required this.mddReader,
    required this.cssContent,
  });

  static Future<MdictDictionary> create(MdictFiles mdictFiles) async {
    final mdxReader = await MdictReader.create(mdictFiles.mdxPath);

    String name = mdxReader.name ?? '';
    if (name.isEmpty) {
      name = MdictHelpers.getDictNameFromPath(mdictFiles.mdxPath);
    }

    MdictReader? mddReader;
    if (mdictFiles.mddPath != null) {
      mddReader = await MdictReader.create(mdictFiles.mddPath!);
    }

    final cssFileContent =
        await MdictHelpers.readFileContent(mdictFiles.cssPath) ?? '';
    final cssMddContent = await mddReader?.extractCss() ?? '';

    return MdictDictionary._(
      name: name,
      mdxReader: mdxReader,
      mddReader: mddReader,
      cssContent: '$cssFileContent\n$cssMddContent'.trim(),
    );
  }

  final String name;
  final MdictReader mdxReader;
  final MdictReader? mddReader;
  final String cssContent;

  String get mdxPath => mdxReader.path;

  Future<MdictSearchResultLists> search(String term) => mdxReader.search(term);

  /// Return [html, css] of result
  Future<List<String>> queryMdx(String keyWord) async {
    var html = await mdxReader.queryMdx(keyWord);
    if (mddReader == null || html.isEmpty) {
      return [html, cssContent];
    }

    try {
      final document = parse(html);

      final images = document.getElementsByTagName('img');
      for (var img in images) {
        final src = img.attributes['src'];

        if (src == null) continue;

        var extension = p.extension(src).toLowerCase();
        if (extension.isEmpty) continue;

        extension = extension.replaceFirst('.', '');

        final intData = await queryResource(src.replaceAll('/', '\\'));
        if (intData == null) continue;

        final base64Data = base64.encode(intData);

        img.attributes['src'] = 'data:image/$extension;base64,$base64Data';
      }

      html = document.body?.innerHtml ?? html;
    } on Exception catch (e) {
      print(e);
    }

    return [html, cssContent];
  }

  Future<Uint8List?> queryResource(String resourceKey) async =>
      mddReader?.queryMdd(resourceKey);
}
