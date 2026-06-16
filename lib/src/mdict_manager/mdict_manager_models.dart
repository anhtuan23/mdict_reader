import 'package:equatable/equatable.dart';
import 'package:mdict_reader/src/mdict_reader/mdict_reader_models.dart';
import 'package:mdict_reader/src/utils.dart';
import 'package:sqlite3/common.dart';

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
  factory SearchReturn.fromQueryReturn(QueryReturn queryReturn) {
    return SearchReturn._(
      queryReturn.word,
      {queryReturn.mdxPath: queryReturn.dictName},
    );
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

/// Represents the progress of an MDICT dictionary operation.
sealed class MdictProgress extends Equatable {
  /// Creates a new [MdictProgress] instance.
  const MdictProgress({this.isFinished = false, this.isError = false});

  /// Whether the operation has completed.
  final bool isFinished;

  /// Whether the operation encountered an error.
  final bool isError;

  @override
  List<Object?> get props => [isFinished, isError];
}

/// Progress status when there is no active operation.
class MdictProgressEmpty extends MdictProgress {
  /// Creates an empty progress status.
  const MdictProgressEmpty() : super(isFinished: true);
}

/// Progress status when an operation has failed with an error.
class MdictProgressError extends MdictProgress {
  /// Creates an error progress status.
  const MdictProgressError(this.error, this.stackTrace) : super(isError: true);

  /// The error message or object.
  final String error;

  /// The stack trace associated with the error.
  final StackTrace stackTrace;

  @override
  List<Object?> get props => [error, stackTrace];
}

// MdictManager progress states

/// Progress status when opening the dictionary database.
class MdictProgressManagerOpenDb extends MdictProgress {
  /// Creates a status indicating the database is opening.
  const MdictProgressManagerOpenDb();
}

/// Progress status when setting up metadata tables.
class MdictProgressManagerCreateMeta extends MdictProgress {
  /// Creates a status indicating metadata table setup.
  const MdictProgressManagerCreateMeta();
}

/// Progress status when counting old records.
class MdictProgressManagerCountOld extends MdictProgress {
  /// Creates a status indicating old record count is in progress.
  const MdictProgressManagerCountOld();
}

/// Progress status when existing dictionary records are found.
class MdictProgressManagerHasOld extends MdictProgress {
  /// Creates a status indicating old records were found.
  const MdictProgressManagerHasOld(this.oldCount, this.dictFileNameExtList);

  /// The number of old records found.
  final int oldCount;

  /// The file name extensions of existing dictionaries.
  final List<String> dictFileNameExtList;

  @override
  List<Object?> get props => [oldCount, dictFileNameExtList];
}

/// Progress status when discarding old table entries.
class MdictProgressManagerDiscardOld extends MdictProgress {
  /// Creates a status indicating an old table is being discarded.
  const MdictProgressManagerDiscardOld(this.tableName);

  /// The name of the table being discarded.
  final String tableName;

  @override
  List<Object?> get props => [tableName];
}

/// Progress status when creating keys table indices.
class MdictProgressManagerCreateKey extends MdictProgress {
  /// Creates a status indicating keys index creation.
  const MdictProgressManagerCreateKey();
}

/// Progress status when creating record table indices.
class MdictProgressManagerCreateRecord extends MdictProgress {
  /// Creates a status indicating record index creation.
  const MdictProgressManagerCreateRecord();
}

/// Progress status when processing a specific dictionary file.
class MdictProgressManagerProcessing extends MdictProgress {
  /// Creates a status indicating dictionary processing.
  const MdictProgressManagerProcessing(this.mdxFileNameExt);

  /// The file name extension of the dictionary being processed.
  final String mdxFileNameExt;

  @override
  List<Object?> get props => [mdxFileNameExt];
}

/// Progress status when querying a word in a specific dictionary.
class MdictProgressManagerQuerying extends MdictProgress {
  /// Creates a status indicating a lookup query.
  const MdictProgressManagerQuerying(this.word, this.dictName);

  /// The word being queried.
  final String word;

  /// The name of the dictionary being queried.
  final String dictName;

  @override
  List<Object?> get props => [word, dictName];
}

/// Progress status when dictionary queries for a word are completed.
class MdictProgressManagerFinishedQuerying extends MdictProgress {
  /// Creates a status indicating finished query.
  const MdictProgressManagerFinishedQuerying(this.word)
    : super(isFinished: true);

  /// The word that was queried.
  final String word;

  @override
  List<Object?> get props => [word];
}

// MdictDictionary progress states

/// Progress status when loading and parsing a dictionary file.
class MdictProgressDictionaryProcessing extends MdictProgress {
  /// Creates a status indicating dictionary file parsing.
  const MdictProgressDictionaryProcessing(this.fileNameExt, this.fileExtension);

  /// The name of the dictionary file.
  final String fileNameExt;

  /// The extension of the file (mdx or mdd).
  final String fileExtension;

  @override
  List<Object?> get props => [fileNameExt, fileExtension];
}

/// Progress status when extracting stylesheet CSS from a dictionary.
class MdictProgressDictionaryGetCss extends MdictProgress {
  /// Creates a status indicating CSS extraction.
  const MdictProgressDictionaryGetCss(this.mdxFileNameExt);

  /// The filename of the dictionary containing the CSS.
  final String mdxFileNameExt;

  @override
  List<Object?> get props => [mdxFileNameExt];
}

/// Progress status when the dictionary representation has been created.
class MdictProgressDictionaryCreatedDict extends MdictProgress {
  /// Creates a status indicating dictionary creation.
  const MdictProgressDictionaryCreatedDict(this.mdxFileNameExt);

  /// The filename of the created dictionary.
  final String mdxFileNameExt;

  @override
  List<Object?> get props => [mdxFileNameExt];
}

// MdictReaderInitHelper progress states

/// Progress status when retrieving index info for a file.
class MdictProgressReaderHelperGetInfo extends MdictProgress {
  /// Creates a status indicating metadata retrieval.
  const MdictProgressReaderHelperGetInfo(this.fileNameExt);

  /// The name of the file being read.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

/// Progress status when reading the header of a file.
class MdictProgressReaderHelperReadHeader extends MdictProgress {
  /// Creates a status indicating header parsing.
  const MdictProgressReaderHelperReadHeader(this.fileNameExt);

  /// The name of the file whose header is being read.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

/// Progress status when reading the keys block of a file.
class MdictProgressReaderHelperReadKeys extends MdictProgress {
  /// Creates a status indicating keys block parsing.
  const MdictProgressReaderHelperReadKeys(this.fileNameExt);

  /// The name of the file whose keys are being read.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

/// Progress status when reading the records block of a file.
class MdictProgressReaderHelperReadRecords extends MdictProgress {
  /// Creates a status indicating record block parsing.
  const MdictProgressReaderHelperReadRecords(this.fileNameExt);

  /// The name of the file whose records are being read.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

/// Progress status when building the database metadata table.
class MdictProgressReaderHelperBuildMeta extends MdictProgress {
  /// Creates a status indicating metadata table build.
  const MdictProgressReaderHelperBuildMeta(this.fileNameExt);

  /// The name of the file for which metadata is being built.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

/// Progress status when building the database keys table.
class MdictProgressReaderHelperBuildKey extends MdictProgress {
  /// Creates a status indicating keys table index build.
  const MdictProgressReaderHelperBuildKey(
    this.fileNameExt,
    this.insertedCount,
    this.totalKeys,
  );

  /// The name of the file.
  final String fileNameExt;

  /// The number of keys inserted so far.
  final int insertedCount;

  /// The total number of keys to insert.
  final int totalKeys;

  @override
  List<Object?> get props => [fileNameExt, insertedCount, totalKeys];
}

/// Progress status when building the database records table.
class MdictProgressReaderHelperBuildRecord extends MdictProgress {
  /// Creates a status indicating record table index build.
  const MdictProgressReaderHelperBuildRecord(this.fileNameExt);

  /// The name of the file.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

/// Progress status when indexing has finished.
class MdictProgressReaderHelperFinishedIndex extends MdictProgress {
  /// Creates a status indicating index build completion.
  const MdictProgressReaderHelperFinishedIndex(this.fileNameExt);

  /// The name of the indexed file.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

/// Progress status when retrieving file headers.
class MdictProgressReaderHelperGetHeaders extends MdictProgress {
  /// Creates a status indicating file header retrieval.
  const MdictProgressReaderHelperGetHeaders(this.fileNameExt);

  /// The name of the file.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

/// Progress status when retrieving the list of records from a file.
class MdictProgressReaderHelperGetRecordList extends MdictProgress {
  /// Creates a status indicating record list retrieval.
  const MdictProgressReaderHelperGetRecordList(this.fileNameExt);

  /// The name of the file.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

/// Progress status when dictionary load/creation is complete.
class MdictProgressReaderHelperFinishedCreateDict extends MdictProgress {
  /// Creates a status indicating dictionary loading completion.
  const MdictProgressReaderHelperFinishedCreateDict(this.fileNameExt);

  /// The name of the loaded file.
  final String fileNameExt;

  @override
  List<Object?> get props => [fileNameExt];
}

// Copy & Delete progress states (from mdict_flutter factories)

/// Progress status when no MDX file was found during import.
class MdictProgressCopyDictNoMdx extends MdictProgress {
  /// Creates a status indicating no MDX file found.
  const MdictProgressCopyDictNoMdx();
}

/// Progress status when adding a dictionary name to the database.
class MdictProgressCopyDictAddDictName extends MdictProgress {
  /// Creates a status indicating dictionary name registration.
  const MdictProgressCopyDictAddDictName(this.dictName);

  /// The name of the dictionary.
  final String dictName;

  @override
  List<Object?> get props => [dictName];
}

/// Progress status when checking the compatibility version of a dictionary.
class MdictProgressCopyDictCheckVersion extends MdictProgress {
  /// Creates a status indicating compatibility check.
  const MdictProgressCopyDictCheckVersion(this.dictName);

  /// The name of the dictionary.
  final String dictName;

  @override
  List<Object?> get props => [dictName];
}

/// Progress status when a dictionary version compatibility check fails.
class MdictProgressCopyDictErrorVersion extends MdictProgress {
  /// Creates an error status indicating incompatible version.
  const MdictProgressCopyDictErrorVersion(this.dictName) : super(isError: true);

  /// The name of the dictionary.
  final String dictName;

  @override
  List<Object?> get props => [dictName];
}

/// Progress status when copying a dictionary file.
class MdictProgressCopyDictCopyFile extends MdictProgress {
  /// Creates a status indicating file copy progress.
  const MdictProgressCopyDictCopyFile(this.filePath);

  /// The target file path.
  final String filePath;

  @override
  List<Object?> get props => [filePath];
}

/// Progress status when adding a dictionary to the loaded list.
class MdictProgressCopyDictAddDictList extends MdictProgress {
  /// Creates a status indicating dictionary list addition.
  const MdictProgressCopyDictAddDictList(this.dictName);

  /// The name of the dictionary.
  final String dictName;

  @override
  List<Object?> get props => [dictName];
}

/// Progress status when dictionary deletion starts.
class MdictProgressDeleteDictStart extends MdictProgress {
  /// Creates a status indicating deletion start.
  const MdictProgressDeleteDictStart(this.dictName);

  /// The name of the dictionary.
  final String dictName;

  @override
  List<Object?> get props => [dictName];
}

/// Progress status when a dictionary delete fails because it does not exist.
class MdictProgressDeleteDictNotExistError extends MdictProgress {
  /// Creates an error status indicating dictionary does not exist.
  const MdictProgressDeleteDictNotExistError(this.dictName)
    : super(isError: true);

  /// The name of the dictionary.
  final String dictName;

  @override
  List<Object?> get props => [dictName];
}

/// Progress status when the dictionary manager finishes initialization.
class MdictProgressApiFinishedInitManager extends MdictProgress {
  /// Creates a finished status for initialization.
  const MdictProgressApiFinishedInitManager() : super(isFinished: true);
}

/// Progress status when insertion of dictionary is complete.
class MdictProgressApiFinishedInsert extends MdictProgress {
  /// Creates a finished status for insertion.
  const MdictProgressApiFinishedInsert() : super(isFinished: true);
}

/// Progress status when dictionary deletion is complete.
class MdictProgressApiFinishedDelete extends MdictProgress {
  /// Creates a finished status for deletion.
  const MdictProgressApiFinishedDelete() : super(isFinished: true);
}

/// Progress status when a dictionary search is complete.
class MdictProgressApiFinishedSearch extends MdictProgress {
  /// Creates a finished status for search.
  const MdictProgressApiFinishedSearch() : super(isFinished: true);
}

/// Progress status when dictionary query lookup is complete.
class MdictProgressApiFinishedQuery extends MdictProgress {
  /// Creates a finished status for query.
  const MdictProgressApiFinishedQuery() : super(isFinished: true);
}

/// Progress status when static resource loading is complete.
class MdictProgressApiFinishedQueryResource extends MdictProgress {
  /// Creates a finished status for resource query.
  const MdictProgressApiFinishedQueryResource() : super(isFinished: true);
}

/// Progress status when dictionaries are reordered.
class MdictProgressApiFinishedReorder extends MdictProgress {
  /// Creates a finished status for reordering.
  const MdictProgressApiFinishedReorder() : super(isFinished: true);
}
