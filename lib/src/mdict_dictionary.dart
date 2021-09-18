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
  });

  static Future<MdictDictionary> create(MdictFiles mdictFiles) async {
    final mdxReader =
        await MdictReader.create(mdictFiles.mdxPath, mdictFiles.cssPath);

    String name = mdxReader.name ?? '';
    if (name.isEmpty) {
      name = MdictHelpers.getDictNameFromPath(mdictFiles.mdxPath);
    }

    MdictReader? mddReader;
    if (mdictFiles.mddPath != null) {
      mddReader =
          await MdictReader.create(mdictFiles.mddPath!, mdictFiles.cssPath);
    }

    return MdictDictionary._(
      name: name,
      mdxReader: mdxReader,
      mddReader: mddReader,
    );
  }

  final String name;
  final MdictReader mdxReader;
  final MdictReader? mddReader;

  String get mdxPath => mdxReader.path;

  Future<MdictSearchResultLists> search(String term) => mdxReader.search(term);

  /// Return [html, css] of result
  Future<List<String>> queryMdx(String keyWord) async {
    final queryResult = await mdxReader.queryMdx(keyWord);
    final html = queryResult[0];
    if (mddReader == null || queryResult[0].isEmpty) return queryResult;

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

      queryResult[0] = document.body?.innerHtml ?? queryResult[0];
    } on Exception catch (e) {
      print(e);
    }

    return queryResult;
  }

  Future<Uint8List?> queryResource(String resourceKey) async =>
      mddReader?.queryMdd(resourceKey);
}
