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

class IsolateSearchResult implements Result {
  const IsolateSearchResult(this.inputHashCode, this.searchResults);
  @override
  final int inputHashCode;
  final List<SearchResult> searchResults;
}

class IsolateQueryResult implements Result {
  const IsolateQueryResult(this.inputHashCode, this.queryResults);
  @override
  final int inputHashCode;
  final List<QueryResult> queryResults;
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
