import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:html/parser.dart' show parse;
import 'package:mdict_reader/mdict_reader.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class MdictDictionary {
  MdictDictionary._({
    required this.mdxReader,
    required this.mddReader,
    required this.cssContent,
  });

  static Future<MdictDictionary> create({
    required MdictFiles mdictFiles,
    required Database db,
    StreamController<MdictProgress>? progressController,
  }) async {
    final mdxFileName = MdictHelpers.getDictNameFromPath(mdictFiles.mdxPath);
    progressController?.add(MdictProgress('Processing $mdxFileName mdx ...'));
    final mdxReader = await MdictReaderInitHelper.init(
      filePath: mdictFiles.mdxPath,
      db: db,
      progressController: progressController,
    );

    MdictReader? mddReader;
    if (mdictFiles.mddPath != null) {
      final mddFileName = MdictHelpers.getDictNameFromPath(mdictFiles.mdxPath);
      progressController?.add(MdictProgress('Processing $mddFileName mdd ...'));
      mddReader = await MdictReaderInitHelper.init(
        filePath: mdictFiles.mddPath!,
        db: db,
        progressController: progressController,
      );
    }

    progressController
        ?.add(MdictProgress('Getting css style of $mdxFileName ...'));
    final cssFileContent =
        await MdictHelpers.readFileContent(mdictFiles.cssPath) ?? '';
    final cssMddContent = await mddReader?.extractCss() ?? '';

    progressController
        ?.add(MdictProgress('Finished creating $mdxFileName dictionary ...'));
    return MdictDictionary._(
      mdxReader: mdxReader,
      mddReader: mddReader,
      cssContent: '$cssFileContent\n$cssMddContent'.trim(),
    );
  }

  final MdictReader mdxReader;
  final MdictReader? mddReader;
  final String cssContent;

  String get name => mdxReader.name;

  String get mdxPath => mdxReader.path;

  /// Return [html, css] of result
  Future<List<String>> queryMdx(String keyWord) async {
    var html = await mdxReader.queryMdx(keyWord);
    if (mddReader == null || html.isEmpty) {
      return [html, cssContent];
    }

    try {
      final document = parse(html);

      final images = document.getElementsByTagName('img');
      for (final img in images) {
        final src = img.attributes['src'];

        if (src == null) continue;

        var extension = p.extension(src).toLowerCase();
        if (extension.isEmpty) continue;

        extension = extension.replaceFirst('.', '');

        final intData = await queryResource(src.replaceAll('/', r'\'));
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
