import 'package:equatable/equatable.dart';

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

class SearchReturn {
  SearchReturn(this.word);

  final String word;
  final Map<String, String> dictPathNameMap = {};

  void addDictInfo(String mdxPath, String dictName) =>
      dictPathNameMap[mdxPath] = dictName;

  @override
  String toString() {
    return 'Word: $word\nDict names: $dictPathNameMap\n';
  }
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
