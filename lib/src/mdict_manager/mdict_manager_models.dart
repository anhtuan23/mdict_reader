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

class SearchResult extends Equatable {
  const SearchResult._(this.word, this.dictPathNameMap);
  factory SearchResult.fromRow(Row row, Map<String, String> allPathNameMap) {
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
    return SearchResult._(MdictKey.getWordFromRow(row), dictPathNameMap);
  }
  factory SearchResult.testResult(String word, List<String> dictPaths) {
    final dictPathNameMap = {for (final key in dictPaths) key: ''};
    return SearchResult._(word, dictPathNameMap);
  }
  factory SearchResult.testResultFromWord(String word) {
    return SearchResult.testResult(word, ['${word}_path.mdx']);
  }
  factory SearchResult.fromQueryResult(QueryResult queryResult) {
    return SearchResult._(
      queryResult.word,
      {queryResult.mdxPath: queryResult.dictName},
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

class QueryResult extends Equatable {
  const QueryResult(
    this.word,
    this.dictName,
    this.mdxPath,
    this.html,
    this.css,
    this.js,
  );
  factory QueryResult.testResult(String word, String mdxPath) {
    return QueryResult(word, '', mdxPath, '', '', '');
  }
  factory QueryResult.testResultFromWord(String word) {
    return QueryResult.testResult(word, '${word}_path.mdx');
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
