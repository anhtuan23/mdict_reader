import 'dart:ffi';
import 'dart:io';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  open.overrideFor(OperatingSystem.windows, _openOnWindows);
  final db = sqlite3.openInMemory();

  /// *** MdictManager ***
  // final mdxPaths = [
  //   // 'dict/CC-CEDICT.mdx',
  //   MdictFiles('dict/JaViDic_Ja-Vi.mdx'),
  //   // 'dict/OALD_8th.mdx',
  //   // 'dict/jmdict.mdx',
  // ];
  // final word = '勉強';
  // // final word = '哽咽';

  // final mdictManager = await MdictManager.create(mdxPaths);
  // final queryReturnList = await mdictManager.query(word);

  // for (var queryReturn in queryReturnList) {
  //   print(queryReturn.html);
  //   print('--------------------------------');
  // }

  /// *** MdictReader ***
  // final mdictReader = await MdictReader.create('./dict/mtBab EV v1.0/mtBab EV v1.0.mdd', null);
  // final mdictReader = await MdictReader.create('./dict/OALD9/oald9.mdd', null);
  final mdictReader = await MdictReaderHelper.init(
    filePath: './dict/CC-CEDICT.mdx',
    currentTableNames: [],
    db: db,
  );

  final searchResults = await mdictReader.search('音');
  print(searchResults);

  final html = await mdictReader.queryMdx('勉強');
  print(html);

  // for (var key in mdictReader.keys()) {
  //   if (key.endsWith('css')) print(key);
  // }

  db.dispose();
}

DynamicLibrary _openOnWindows() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final libraryNextToScript = File('${scriptDir.path}\\sqlite3.dll');
  return DynamicLibrary.open(libraryNextToScript.path);
}
