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
  SearchReturn._(this.word, this.dictPathNameMap);

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

class QueryReturn {
  const QueryReturn(
    this.word,
    this.dictName,
    this.mdxPath,
    this.html,
    this.css,
  );

  final String word;
  final String dictName;
  final String mdxPath;
  final String html;
  final String css;

  @override
  String toString() {
    return 'Word: $word\nDictname: $dictName\nHtml: $html\nCss: $css\n';
  }
}

class MdictProgress extends Equatable {
  const MdictProgress(this.message);

  final String message;

  @override
  String toString() {
    return 'MdictProgress: $message';
  }

  @override
  List<Object?> get props => [message];
}
