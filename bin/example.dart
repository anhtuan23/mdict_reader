import 'dart:ffi';
import 'dart:io';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:sqlite3/open.dart';

void main() async {
  const tempDbPath = 'bin/example.db';

  open.overrideFor(OperatingSystem.windows, _openOnWindows);
  // final db = sqlite3.open();

  final mdictFilesList = [
    const MdictFiles(
      'dict/CC-CEDICT.mdx',
      'dict/CC-CEDICT.mdd',
      null,
    ),
    const MdictFiles(
      'dict/jmdict_v2.mdx',
      null,
      null,
    ),
    const MdictFiles(
      'dict/wordnet20_v2.mdx',
      null,
      null,
    ),
    const MdictFiles(
      'dict/cc_cedict_v2.mdx',
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
    'work',
    'city',
  ];

  final stopWatch = Stopwatch()..start();

  final mdictManager = await MdictManager.create(
    mdictFilesIter: mdictFilesList,
    dbPath: tempDbPath,
  );
  print('Create manager took ${stopWatch.elapsed}');

  stopWatch.reset();
  for (final word in words) {
    // ignore: unused_local_variable
    final searchReturnList = await mdictManager.search(word);
    // print(searchReturnList);
  }
  print('Search took ${stopWatch.elapsed}');

  stopWatch.reset();
  for (final word in words) {
    // ignore: unused_local_variable
    final queryReturnList = await mdictManager.query(word);
  }
  print('Query took ${stopWatch.elapsed}');
  // print(queryReturnList);

  stopWatch.stop();
  mdictManager.dispose();
}

DynamicLibrary _openOnWindows() {
  final scriptDir = File(Platform.script.toFilePath()).parent;
  final libraryNextToScript = File('${scriptDir.path}\\sqlite3.dll');
  return DynamicLibrary.open(libraryNextToScript.path);
}
