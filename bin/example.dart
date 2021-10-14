import 'dart:ffi';
import 'dart:io';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() async {
  open.overrideFor(OperatingSystem.windows, _openOnWindows);
  final db = sqlite3.openInMemory();

  final mdictFilesList = [
    const MdictFiles(
      'test/assets/CC-CEDICT/CC-CEDICT.mdx',
      'test/assets/CC-CEDICT/CC-CEDICT.mdd',
      'test/assets/CC-CEDICT/CC-CEDICT.css',
    ),
    const MdictFiles(
      'test/assets/jmdict_v2.mdx',
      null,
      null,
    ),
    const MdictFiles(
      'test/assets/wordnet20_v2.mdx',
      null,
      null,
    ),
  ];

  final words = [
    'c',
    'co',
    'con',
    'cont',
    'conti',
    'contin',
    'contine',
    'continen',
    'continent',
  ];

  final stopWatch = Stopwatch();
  stopWatch.start();

  MdictManager mdictManager = await MdictManager.create(
    mdictFilesIter: mdictFilesList,
    dbPath: null,
  );
  print('Create manager took ${stopWatch.elapsed}');

  stopWatch.reset();
  for (var word in words) {
    // ignore: unused_local_variable
    final searchReturnList = await mdictManager.search(word);
    // print(searchReturnList);
  }
  print('Search took ${stopWatch.elapsed}');

  stopWatch.reset();
  for (var word in words) {
    // ignore: unused_local_variable
    final queryReturnList = await mdictManager.query(word);
  }
  print('Query took ${stopWatch.elapsed}');
  // print(queryReturnList);

  stopWatch.stop();
  db.dispose();
}

DynamicLibrary _openOnWindows() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final libraryNextToScript = File('${scriptDir.path}\\sqlite3.dll');
  return DynamicLibrary.open(libraryNextToScript.path);
}
