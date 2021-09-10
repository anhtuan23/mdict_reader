import 'package:mdict_reader/mdict_reader.dart';
import 'package:test/test.dart';

void main() {
  final mdictFilesList = [
    MdictFiles(
      'test/assets/CC-CEDICT/CC-CEDICT.mdx',
      'test/assets/CC-CEDICT/CC-CEDICT.css',
    ),
    MdictFiles(
      'test/assets/jmdict_v2.mdx',
    ),
    MdictFiles(
      'test/assets/wordnet20_v2.mdx',
    ),
  ];

  final word = '勉強';

  late MdictManager mdictManager;

  setUp(() async {
    mdictManager = await MdictManager.create(mdictFilesList);
  });

  test('search function', () async {
    final searchReturnList = await mdictManager.search(word);

    printOnFailure(searchReturnList.toString());

    expect(searchReturnList, hasLength(20));
    expect(searchReturnList[0].word, equals('勉強'));
    expect(searchReturnList[0].dictNames, equals(['CC-CEDICT', 'JMDict']));
  });

  test('query function', () async {
    final queryReturnList = await mdictManager.query(word);

    printOnFailure(queryReturnList.toString());

    expect(queryReturnList, hasLength(2));

    final firstDictReturn = queryReturnList[0];
    expect(firstDictReturn.word, equals('勉強'));
    expect(firstDictReturn.dictName, equals('CC-CEDICT'));
    expect(firstDictReturn.html, isNotEmpty);
    expect(firstDictReturn.css, isNotEmpty);

    final secondDictReturn = queryReturnList[1];
    expect(secondDictReturn.word, equals('勉強'));
    expect(secondDictReturn.dictName, equals('JMDict'));
    expect(secondDictReturn.html, isNotEmpty);
    expect(secondDictReturn.css, isEmpty);
  });

  test('reOrder function', () async {
    var pathNameMap = mdictManager.pathNameMap;
    expect(pathNameMap.values, equals(['CC-CEDICT', 'JMDict', 'WordNet 2.0']));

    mdictManager = mdictManager.reOrder(2, 0);
    pathNameMap = mdictManager.pathNameMap;
    expect(pathNameMap.values, equals(['WordNet 2.0', 'CC-CEDICT', 'JMDict']));
  });
}
