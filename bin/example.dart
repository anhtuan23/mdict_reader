import 'package:mdict_reader/mdict_reader.dart';

void main() async {
  const tempDbPath = 'bin/example.db';
  // sqlite3 3.x uses Dart native assets to select the platform library. Older
  // versions required a manual Windows override here, but keeping that hook
  // would break because package:sqlite3/open.dart no longer exists.
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
    await mdictManager.search(word);
    // print(searchReturnList);
  }
  print('Search took ${stopWatch.elapsed}');
  stopWatch.reset();
  for (final word in words) {
    await mdictManager.query(word);
  }
  print('Query took ${stopWatch.elapsed}');
  // print(queryReturnList);
  stopWatch.stop();
  await mdictManager.dispose();
}
