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
    required this.jsContent,
  });

  static Future<MdictDictionary> create({
    required MdictFiles mdictFiles,
    required Database db,
    StreamController<MdictProgress>? progressController,
  }) async {
    final mdxFileNameExt =
        MdictHelpers.getFileNameWithExtensionFromPath(mdictFiles.mdxPath);
    progressController?.add(
      MdictProgress.mdictDictionaryProcessing(mdxFileNameExt, 'mdx'),
    );
    final mdxReader = await MdictReaderInitHelper.init(
      filePath: mdictFiles.mdxPath,
      db: db,
      progressController: progressController,
    );

    MdictReader? mddReader;
    if (mdictFiles.mddPath != null) {
      final mddFileNameExt =
          MdictHelpers.getFileNameWithExtensionFromPath(mdictFiles.mdxPath);
      progressController?.add(
        MdictProgress.mdictDictionaryProcessing(mddFileNameExt, 'mdd'),
      );
      mddReader = await MdictReaderInitHelper.init(
        filePath: mdictFiles.mddPath!,
        db: db,
        progressController: progressController,
      );
    }

    progressController
        ?.add(MdictProgress.mdictDictionaryGetCss(mdxFileNameExt));
    // Priortize css from separate css file over from mdd.
    var cssContent =
        await MdictHelpers.readFileContent(mdictFiles.cssPath) ?? '';
    cssContent = cssContent.trim();
    if (cssContent.isEmpty) {
      cssContent = await mddReader?.extractScriptContent(getCss: true) ?? '';
      cssContent = cssContent.trim();
    }
    if (cssContent.isNotEmpty && mddReader != null) {
      cssContent = await mddReader.replaceCssUrl(cssContent);
    }

    var jsContent = await mddReader?.extractScriptContent(getCss: false) ?? '';
    jsContent = jsContent.trim();

    progressController
        ?.add(MdictProgress.mdictDictionaryCreatedDict(mdxFileNameExt));
    return MdictDictionary._(
      mdxReader: mdxReader,
      mddReader: mddReader,
      cssContent: cssContent,
      jsContent: jsContent,
    );
  }

  final MdictReader mdxReader;
  final MdictReader? mddReader;
  final String cssContent;
  final String jsContent;

  String get name {
    var name = mdxReader.name?.trim();
    if (name == null ||
        name.isEmpty ||
        name == 'Title (No HTML code allowed)') {
      name =
          MdictHelpers.getFileNameFromPath(mdxReader.path, toLowerCase: false);
    }
    return name;
  }

  String get mdxPath => mdxReader.path;

  /// Return result of [html, css, js]
  Future<List<String>> queryMdx(String keyWord) async {
    var html = await mdxReader.queryMdx(keyWord);
    if (mddReader == null || html.isEmpty) {
      return [html, cssContent, jsContent];
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

    return [html, cssContent, jsContent];
  }

  Future<Uint8List?> queryResource(String resourceKey) async =>
      mddReader?.queryMdd(resourceKey);
}
