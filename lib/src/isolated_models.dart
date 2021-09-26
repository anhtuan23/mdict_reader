import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:mdict_reader/src/mdict_manager_models.dart';

class InitManagerInput extends Equatable {
  const InitManagerInput(
    this.dbPath,
    this.mdictFilesIter,
  );

  final String? dbPath;
  final Iterable<MdictFiles> mdictFilesIter;

  @override
  List<Object?> get props => [dbPath, mdictFilesIter];
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
  const SearchResult(this.inputHashCode, this.searchReturnList);

  @override
  final int inputHashCode;
  final List<SearchReturn> searchReturnList;
}

/// [mdxPaths] narrow down which dictionary to query if provided
class QueryInput extends Equatable {
  const QueryInput(this.word, [this.mdxPaths]);

  final String word;
  final Set<String>? mdxPaths;

  @override
  List<Object?> get props => [word, mdxPaths];
}

class QueryResult implements Result {
  const QueryResult(this.inputHashCode, this.queryReturns);

  @override
  final int inputHashCode;
  final List<QueryReturn> queryReturns;
}

/// [mdxPath] act as a key when we want to query resource from a specific dictionary
class ResourceQueryInput extends Equatable {
  const ResourceQueryInput(
    this.resourceUri,
    this.mdxPath,
  );
  final String resourceUri;
  final String? mdxPath;

  @override
  List<Object?> get props => [resourceUri];
}

class ResourceQueryResult implements Result {
  const ResourceQueryResult(this.inputHashCode, this.resourceData);

  @override
  final int inputHashCode;
  final Uint8List? resourceData;
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
