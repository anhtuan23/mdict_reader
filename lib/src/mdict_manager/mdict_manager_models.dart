import 'package:equatable/equatable.dart';
import 'package:mdict_reader/src/mdict_reader/mdict_reader_models.dart';
import 'package:mdict_reader/src/utils.dart';
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
    final dictFileNameExtList = MdictKey.getFileNamesFromRow(row);

    final dictPathNameMap = <String, String>{};
    for (final fileNameExt in dictFileNameExtList) {
      for (final path in allPathNameMap.keys) {
        if (MdictHelpers.getFileNameWithExtensionFromPath(path) ==
            fileNameExt) {
          dictPathNameMap[path] = allPathNameMap[path]!;
          break;
        }
      }
    }

    return SearchReturn._(MdictKey.getWordFromRow(row), dictPathNameMap);
  }

  factory SearchReturn.testResult(String word, List<String> dictPaths) {
    final dictPathNameMap = {for (final key in dictPaths) key: ''};
    return SearchReturn._(word, dictPathNameMap);
  }

  factory SearchReturn.testReturnFromWord(String word) {
    return SearchReturn.testResult(word, ['${word}_path.mdx']);
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
    this.js,
  );

  factory QueryReturn.testReturn(String word, String mdxPath) {
    return QueryReturn(word, '', mdxPath, '', '', '');
  }

  factory QueryReturn.testReturnFromWord(String word) {
    return QueryReturn.testReturn(word, '${word}_path.mdx');
  }

  final String word;
  final String dictName;
  final String mdxPath;
  final String html;
  final String css;
  final String js;

  @override
  String toString() {
    return 'Word: $word\nDictname: $dictName\nHtml: $html\nCss: $css\nJS: $js';
  }

  @override
  List<Object?> get props => [word, mdxPath];
}

class MdictProgress extends Equatable {
  const MdictProgress({
    required this.messageType,
    this.addedInfoList = const [],
    this.isError = false,
    this.isFinished = false,
  });

  const MdictProgress.empty() : this(messageType: 'empty', isFinished: true);

  MdictProgress.error(String errorString, StackTrace stackTrace)
      : this(
          messageType: 'error',
          addedInfoList: [errorString, stackTrace.toString()],
          isError: true,
        );

  // * MdictManager
  // Opening index database ...
  const MdictProgress.mdictManagerOpenDb()
      : this(messageType: 'mdictManagerOpenDb');

  // createTables: createMeta
  const MdictProgress.mdictManagerCreateMeta()
      : this(messageType: 'mdictManagerCreateMeta');

  // createTables: count old
  const MdictProgress.mdictManagerCountOld()
      : this(messageType: 'mdictManagerCountOld');

  // createTables: has old
  MdictProgress.mdictManagerHasOld(
    int oldCount,
    List<String> dictFileNameExtList,
  ) : this(
          messageType: 'mdictManagerHasOld',
          addedInfoList: [oldCount.toString(), dictFileNameExtList.toString()],
        );

  // createTables: discard old
  MdictProgress.mdictManagerDiscardOld(String tableName)
      : this(
          messageType: 'mdictManagerDiscardOld',
          addedInfoList: [tableName],
        );

  // createTables: createKey
  const MdictProgress.mdictManagerCreateKey()
      : this(messageType: 'mdictManagerCreateKey');

  // createTables: createRecord
  const MdictProgress.mdictManagerCreateRecord()
      : this(messageType: 'mdictManagerCreateRecord');

  // Processing $mdxFileName ...
  MdictProgress.mdictManagerProcessing(String mdxFileNameExt)
      : this(
          messageType: 'mdictManagerProcessing',
          addedInfoList: [mdxFileNameExt],
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
          isFinished: true,
        );

  // * MdictDictionary
  // Processing $mdxFileName mdx ...
  // Processing $mddFileName mdd ...
  MdictProgress.mdictDictionaryProcessing(
    String fileNameExt,
    String fileExtension,
  ) : this(
          messageType: 'mdictDictionaryProcessing',
          addedInfoList: [fileNameExt, fileExtension],
        );

  // Getting css style of $mdxFileName ...
  MdictProgress.mdictDictionaryGetCss(String mdxFileNameExt)
      : this(
          messageType: 'mdictDictionaryGetCss',
          addedInfoList: [mdxFileNameExt],
        );

  // Finished creating $mdxFileName dictionary ...
  MdictProgress.mdictDictionaryCreatedDict(String mdxFileNameExt)
      : this(
          messageType: 'mdictDictionaryCreatedDict',
          addedInfoList: [mdxFileNameExt],
        );

  // * MdictReaderInitHelper
  // Getting index info for $fileName ...
  MdictProgress.readerHelperGetInfo(String fileNameExt)
      : this(
          messageType: 'readerHelperGetInfo',
          addedInfoList: [fileNameExt],
        );

  // Reading header of $fileName ...
  MdictProgress.readerHelperReadHeader(String fileNameExt)
      : this(
          messageType: 'readerHelperReadHeader',
          addedInfoList: [fileNameExt],
        );

  // Reading keys of $fileName ...
  MdictProgress.readerHelperReadKeys(String fileNameExt)
      : this(
          messageType: 'readerHelperReadKeys',
          addedInfoList: [fileNameExt],
        );

  // Reading records of $fileName ...
  MdictProgress.readerHelperReadRecords(String fileNameExt)
      : this(
          messageType: 'readerHelperReadRecords',
          addedInfoList: [fileNameExt],
        );

  // Building meta table for $fileName ...
  MdictProgress.readerHelperBuildMeta(String fileNameExt)
      : this(
          messageType: 'readerHelperBuildMeta',
          addedInfoList: [fileNameExt],
        );

  // Building key table for $fileName: $insertedCount/$totalKeys ...
  MdictProgress.readerHelperBuildKey(
    String fileNameExt,
    int insertedCount,
    int totalKeys,
  ) : this(
          messageType: 'readerHelperBuildKey',
          addedInfoList: [
            fileNameExt,
            insertedCount.toString(),
            totalKeys.toString(),
          ],
        );

  // Building records table for $fileName ...
  MdictProgress.readerHelperBuildRecord(String fileNameExt)
      : this(
          messageType: 'readerHelperBuildRecord',
          addedInfoList: [fileNameExt],
        );

  // Finished building index for $fileName ...
  MdictProgress.readerHelperFinishedIndex(String fileNameExt)
      : this(
          messageType: 'readerHelperFinishedIndex',
          addedInfoList: [fileNameExt],
        );

  // Getting headers of $fileName ...
  MdictProgress.readerHelperGetHeaders(String fileNameExt)
      : this(
          messageType: 'readerHelperGetHeaders',
          addedInfoList: [fileNameExt],
        );

  // Getting record list of $fileName ...
  MdictProgress.readerHelperGetRecordList(String fileNameExt)
      : this(
          messageType: 'readerHelperGetRecordList',
          addedInfoList: [fileNameExt],
        );

  // Finished creating $fileName dictionary
  MdictProgress.readerHelperFinishedCreateDict(String fileNameExt)
      : this(
          messageType: 'readerHelperFinishedCreateDict',
          addedInfoList: [fileNameExt],
        );

  final String messageType;
  final List<String> addedInfoList;
  final bool isError;
  final bool isFinished;

  @override
  String toString() =>
      // ignore: lines_longer_than_80_chars
      'MdictProgress($messageType, $addedInfoList, isError: $isError, isFinished: $isFinished)';

  @override
  List<Object?> get props => [messageType];
}
