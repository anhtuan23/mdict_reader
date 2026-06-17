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
