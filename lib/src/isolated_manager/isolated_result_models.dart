import 'dart:typed_data';

import 'package:mdict_reader/src/mdict_manager/mdict_manager_models.dart';

abstract class Result {
  abstract final int inputHashCode;
}

class PathNameMapResult implements Result {
  const PathNameMapResult(this.inputHashCode, this.pathNameMap);

  @override
  final int inputHashCode;
  final Map<String, String> pathNameMap;
}

class SearchResult implements Result {
  const SearchResult(this.inputHashCode, this.searchReturnList);

  @override
  final int inputHashCode;
  final List<SearchReturn> searchReturnList;
}

class QueryResult implements Result {
  const QueryResult(this.inputHashCode, this.queryReturns);

  @override
  final int inputHashCode;
  final List<QueryReturn> queryReturns;
}

class ResourceQueryResult implements Result {
  const ResourceQueryResult(this.inputHashCode, this.resourceData);

  @override
  final int inputHashCode;
  final Uint8List? resourceData;
}

class ErrorResult implements Result {
  const ErrorResult(this.inputHashCode, this.error, this.stackTrace);

  @override
  final int inputHashCode;
  final Object error;
  final StackTrace stackTrace;
}
