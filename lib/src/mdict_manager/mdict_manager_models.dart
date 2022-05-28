import 'package:equatable/equatable.dart';
import 'package:mdict_reader/src/mdict_reader/mdict_reader_models.dart';
import 'package:sqlite3/sqlite3.dart';

/// Need a stable hash to work with IsolatedManager's reload
class MdictFiles extends Equatable {
  const MdictFiles(
    this.mdxPath,
    this.mddPath,
    this.cssPath,
  );

  final String mdxPath;
  final String? mddPath;
  final String? cssPath;

  @override
  List<Object?> get props => [mdxPath, mddPath, cssPath];
}

class SearchReturn extends Equatable {
  const SearchReturn._(this.word, this.dictPathNameMap);

  factory SearchReturn.fromRow(Row row, Map<String, String> allPathNameMap) {
    final dictPaths = MdictKey.getFilePathsFromRow(row);
    final dictPathNameMap = {
      for (var path in dictPaths)
        if (allPathNameMap[path] != null) path: allPathNameMap[path]!
    };
    return SearchReturn._(MdictKey.getWordFromRow(row), dictPathNameMap);
  }

  factory SearchReturn.testResult(String word, List<String> dictPaths) {
    final dictPathNameMap = {for (final key in dictPaths) key: ''};
    return SearchReturn._(word, dictPathNameMap);
  }

  final String word;
  final Map<String, String> dictPathNameMap;

  @override
  String toString() {
    return 'Word: $word\nDict names: $dictPathNameMap\n';
  }

  @override
  List<Object?> get props => [word, ...dictPathNameMap.keys];
}

class QueryReturn extends Equatable {
  const QueryReturn(
    this.word,
    this.dictName,
    this.mdxPath,
    this.html,
    this.css,
  );

  factory QueryReturn.testReturn(String word, String mdxPath) {
    return QueryReturn(word, '', mdxPath, '', '');
  }

  final String word;
  final String dictName;
  final String mdxPath;
  final String html;
  final String css;

  @override
  String toString() {
    return 'Word: $word\nDictname: $dictName\nHtml: $html\nCss: $css\n';
  }

  @override
  List<Object?> get props => [word, mdxPath];
}

class MdictProgress extends Equatable {
  const MdictProgress({
    required this.messageType,
    this.addedInfoList = const [],
  });

  const MdictProgress.empty() : this(messageType: 'empty');

  const MdictProgress.error({List<String> addedInfoList = const []})
      : this(messageType: 'error', addedInfoList: addedInfoList);

  // * MdictManager
  // Opening index database ...
  const MdictProgress.mdictManagerOpenIndex()
      : this(messageType: 'mdictManagerOpenIndex');

  // Processing $mdxFileName ...
  MdictProgress.mdictManagerProcessing(String mdxFileName)
      : this(
          messageType: 'mdictManagerProcessing',
          addedInfoList: [mdxFileName],
        );
  // Querying for $word in ${dictionary.name} ...
  MdictProgress.mdictManagerQuerying(String word, String dictName)
      : this(
          messageType: 'mdictManagerQuerying',
          addedInfoList: [word, dictName],
        );

  // Finished querying for $word ...
  MdictProgress.mdictManagerFinishedQuerying(String word)
      : this(
          messageType: 'mdictManagerFinishedQuerying',
          addedInfoList: [word],
        );

  // * MdictDictionary
  // Processing $mdxFileName mdx ...
  // Processing $mddFileName mdd ...
  MdictProgress.mdictDictionaryProcessing(
    String fileName,
    String fileExtension,
  ) : this(
          messageType: 'mdictDictionaryProcessing',
          addedInfoList: [fileName, fileExtension],
        );

  // Getting css style of $mdxFileName ...
  MdictProgress.mdictDictionaryGetCss(String mdxFileName)
      : this(
          messageType: 'mdictDictionaryGetCss',
          addedInfoList: [mdxFileName],
        );

  // Finished creating $mdxFileName dictionary ...
  MdictProgress.mdictDictionaryCreatedDict(String mdxFileName)
      : this(
          messageType: 'mdictDictionaryCreatedDict',
          addedInfoList: [mdxFileName],
        );

  // * MdictReaderInitHelper
  // Getting index info for $fileName ...
  MdictProgress.readerHelperGetInfo(String fileName)
      : this(
          messageType: 'readerHelperGetInfo',
          addedInfoList: [fileName],
        );

  // Building meta table for $fileName ...
  MdictProgress.readerHelperBuildMeta(String fileName)
      : this(
          messageType: 'readerHelperBuildMeta',
          addedInfoList: [fileName],
        );

  // Building key table for $fileName: $insertedCount/$totalKeys ...
  MdictProgress.readerHelperBuildKey(
    String fileName,
    int insertedCount,
    int totalKeys,
  ) : this(
          messageType: 'readerHelperBuildKey',
          addedInfoList: [
            fileName,
            insertedCount.toString(),
            totalKeys.toString(),
          ],
        );

  // Building records table for $fileName ...
  MdictProgress.readerHelperBuildRecord(String fileName)
      : this(
          messageType: 'readerHelperBuildRecord',
          addedInfoList: [fileName],
        );

  // Finished building index for $fileName ...
  MdictProgress.readerHelperFinishedIndex(String fileName)
      : this(
          messageType: 'readerHelperFinishedIndex',
          addedInfoList: [fileName],
        );

  // Getting headers of $fileName ...
  MdictProgress.readerHelperGetHeaders(String fileName)
      : this(
          messageType: 'readerHelperGetHeaders',
          addedInfoList: [fileName],
        );

  // Getting record list of $fileName ...
  MdictProgress.readerHelperGetRecordList(String fileName)
      : this(
          messageType: 'readerHelperGetRecordList',
          addedInfoList: [fileName],
        );

  // Finished creating $fileName dictionary
  MdictProgress.readerHelperFinishedCreateDict(String fileName)
      : this(
          messageType: 'readerHelperFinishedCreateDict',
          addedInfoList: [fileName],
        );

  final String messageType;
  final List<String> addedInfoList;

  @override
  String toString() => 'MdictProgress($messageType, $addedInfoList)';

  @override
  List<Object?> get props => [messageType];
}
