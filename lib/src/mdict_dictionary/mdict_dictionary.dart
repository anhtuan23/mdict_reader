import 'dart:async';
import 'dart:typed_data';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_dictionary/mdict_dictionary_helper.dart';
import 'package:sqlite3/common.dart';

class MdictDictionary {
  MdictDictionary._({
    required this.mdxReader,
    required this.mddReader,
    required this.cssContent,
    required this.jsContent,
  });
  static Future<MdictDictionary> create({
    required MdictFiles mdictFiles,
    required CommonDatabase db,
    StreamController<MdictProgress>? progressController,
  }) async {
    final mdxFileNameExt = MdictHelpers.getFileNameWithExtensionFromPath(
      mdictFiles.mdxPath,
    );
    progressController?.add(
      MdictProgressDictionaryProcessing(mdxFileNameExt, 'mdx'),
    );
    final mdxReader = await MdictReaderInitHelper.init(
      filePath: mdictFiles.mdxPath,
      db: db,
      progressController: progressController,
    );
    MdictReader? mddReader;
    if (mdictFiles.mddPath != null) {
      final mddFileNameExt = MdictHelpers.getFileNameWithExtensionFromPath(
        mdictFiles.mdxPath,
      );
      progressController?.add(
        MdictProgressDictionaryProcessing(mddFileNameExt, 'mdd'),
      );
      mddReader = await MdictReaderInitHelper.init(
        filePath: mdictFiles.mddPath!,
        db: db,
        progressController: progressController,
      );
    }
    progressController?.add(
      MdictProgressDictionaryGetCss(mdxFileNameExt),
    );
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
    progressController?.add(
      MdictProgressDictionaryCreatedDict(mdxFileNameExt),
    );
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
      name = MdictHelpers.getFileNameFromPath(
        mdxReader.path,
        toLowerCase: false,
      );
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
    html = await MdictDictionaryHelper.inlineImages(
      html: html,
      queryResource: queryResource,
    );
    return [html, cssContent, jsContent];
  }

  Future<Uint8List?> queryResource(String resourceKey) async =>
      mddReader?.queryMdd(resourceKey);

  /// Closes and releases resources for both the MDX (definitions) and MDD
  /// (resources) file readers associated with this dictionary. This ensures
  /// that the underlying file descriptors are properly closed when the
  /// dictionary is unloaded.
  Future<void> dispose() async {
    await mdxReader.dispose();
    await mddReader?.dispose();
  }
}
