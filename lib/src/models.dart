import 'package:equatable/equatable.dart';

class InitManagerInput extends Equatable {
  const InitManagerInput(this.pathList);
  final List<String> pathList;

  @override
  List<Object?> get props => [pathList];
}

class PathNameMapResult implements Result {
  const PathNameMapResult(this.inputHashCode, this.pathNamePath);

  @override
  final int inputHashCode;
  final Map<String, String> pathNamePath;
}

class SearchInput extends Equatable {
  const SearchInput(this.term);
  final String term;

  @override
  List<Object?> get props => [term];
}

class SearchResult implements Result {
  const SearchResult(this.inputHashCode, this.searchResult);

  @override
  final int inputHashCode;
  final Map<String, List<String>> searchResult;
}

class QueryInput extends Equatable {
  const QueryInput(this.word);
  final String word;

  @override
  List<Object?> get props => [word];
}

class QueryResult implements Result {
  const QueryResult(this.inputHashCode, this.queryResult);

  @override
  final int inputHashCode;
  final Map<String, String> queryResult;
}

class ReOrderInput extends Equatable {
  const ReOrderInput(this.oldIndex, this.newIndex);
  final int oldIndex;
  final int newIndex;

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

abstract class Result {
  abstract final int inputHashCode;
}
