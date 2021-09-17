import 'dart:typed_data';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/mdict_reader.dart';

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
  Future<List<String>> queryMdx(String keyWord) => mdxReader.queryMdx(keyWord);

  Future<Uint8List?> queryResource(String resourceKey) async =>
      mddReader?.queryMdd(resourceKey);
}
