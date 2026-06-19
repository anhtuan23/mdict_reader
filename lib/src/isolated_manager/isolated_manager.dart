import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/isolated_manager/isolated_input_models.dart';
import 'package:mdict_reader/src/isolated_manager/isolated_result_models.dart';

class IsolatedManager {
  IsolatedManager(
    this._isolateSendPort,
    this._resultStreamController,
    this._progressStreamController,
    this._managerInitCompleter,
  );
  final SendPort _isolateSendPort;
  final Completer<void> _managerInitCompleter;
  final StreamController<dynamic> _resultStreamController;
  final StreamController<MdictProgress> _progressStreamController;
  Stream<MdictProgress> get progressStream => _progressStreamController.stream;
  static Future<IsolatedManager> init(
    Iterable<MdictFiles> mdictFilesIter,
    String? dbPath,
  ) async {
    final resultStreamController = StreamController<dynamic>.broadcast();
    final progressStreamController = StreamController<MdictProgress>();
    final managerInitCompleter = Completer<void>();
    final isolateSendPort = await _initIsolate(
      resultStreamController,
      progressStreamController,
      managerInitCompleter,
    );

    /// Begin to create manager right away
    final input = InitManagerInput(dbPath, mdictFilesIter);
    isolateSendPort.send(input);
    return IsolatedManager(
      isolateSendPort,
      resultStreamController,
      progressStreamController,
      managerInitCompleter,
    );
  }

  static Future<SendPort> _initIsolate(
    StreamController<dynamic> resultStreamController,
    StreamController<MdictProgress> progressStreamController,
    Completer<void> managerInitCompleter,
  ) async {
    final isolateSendPortCompleter = Completer<SendPort>();
    final mainReceivePort = ReceivePort()
      ..listen((dynamic data) {
        if (data is SendPort) {
          isolateSendPortCompleter.complete(data);
        }
        /// On initial init a [PathNameMapResult] will be returned
        /// use this value to mark completer as completed
        /// Data is PathNameMapResult means manager is initialized
        else if (data is PathNameMapResult &&
            !managerInitCompleter.isCompleted) {
          managerInitCompleter.complete();
        } else if (data is MdictProgress) {
          progressStreamController.add(data);
        } else if (data == null) {
          throw Exception('Isolate is terminated');
        } else {
          resultStreamController.add(data);
        }
      });
    await Isolate.spawn(
      _myIsolate,
      mainReceivePort.sendPort,
      onError: mainReceivePort.sendPort,
      onExit: mainReceivePort.sendPort,
    );
    return isolateSendPortCompleter.future;
  }

  static void _myIsolate(SendPort mainSendPort) {
    final isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);
    final progressStreamController = StreamController<MdictProgress>();
    // Note: since this is not a synchronous stream controller,
    // events added will be listened a bit later
    // https://api.dart.dev/dev/2.8.0-dev.3.0/dart-async/SynchronousStreamController-class.html
    progressStreamController.stream.listen(mainSendPort.send);
    MdictManager? manager;
    isolateReceivePort.listen((dynamic data) async {
      try {
        // First data is mdict paths to init dictionary
        if (data is InitManagerInput) {
          // If a manager was already initialized, we must dispose of it first
          // to close any open file handles and the SQLite database connection.
          // This prevents file/resource leaks when reloading dictionaries.
          final oldManager = manager;
          if (oldManager != null) {
            await oldManager.dispose();
          }
          final newManager = await MdictManager.create(
            mdictFilesIter: data.mdictFilesIter,
            dbPath: data.dbPath,
            progressController: progressStreamController,
          );
          manager = newManager;
          mainSendPort.send(
            PathNameMapResult(data.hashCode, newManager.pathNameMap),
          );
        } else if (data is SearchInput) {
          final searchReturnList = await manager!.search(
            data.term,
            data.alternativeTerms,
          );
          mainSendPort.send(
            IsolateSearchResult(data.hashCode, searchReturnList),
          );
        } else if (data is QueryInput) {
          final queryResult = await manager!.query(data.word, data.mdxPaths);
          mainSendPort.send(
            IsolateQueryResult(data.hashCode, queryResult),
          );
        } else if (data is ResourceQueryInput) {
          final resourceData = await manager!.queryResource(
            data.resourceUri,
            data.mdxPath,
          );
          mainSendPort.send(
            ResourceQueryResult(data.hashCode, resourceData),
          );
        } else if (data is ReOrderInput) {
          final updated = manager!.reorder(data.oldIndex, data.newIndex);
          manager = updated;
          mainSendPort.send(
            PathNameMapResult(data.hashCode, updated.pathNameMap),
          );
        }
      } on Object catch (e, stackTrace) {
        // This worker isolate cannot throw directly to the caller isolate, so
        // package the thrown object and stack trace into the normal result
        // stream for the public search/query methods to handle.
        mainSendPort.send(ErrorResult(data.hashCode, e, stackTrace));
      }
    });
  }

  Future<Result> _doWork<I>(
    I input,
    void Function(Object, StackTrace)? onError,
  ) async {
    if (!_managerInitCompleter.isCompleted) {
      await _managerInitCompleter.future;
      return _doWork(input, onError);
    } else {
      _isolateSendPort.send(input);
      final completer = Completer<Result>();
      StreamSubscription<dynamic>? streamSubscription;
      streamSubscription = _resultStreamController.stream.listen((
        dynamic result,
      ) {
        if (result is Result && result.inputHashCode == input.hashCode) {
          if (result is ErrorResult) {
            if (onError != null) {
              onError(result.error, result.stackTrace);
            } else {
              print(result.error);
              print(result.stackTrace);
            }
          }
          completer.complete(result);
          unawaited(streamSubscription?.cancel());
        }
      });
      return completer.future;
    }
  }

  Future<List<SearchResult>> search(
    String term, [
    List<String>? alternativeTerms,
    void Function(Object, StackTrace)? onError,
  ]) async {
    final input = SearchInput(term, alternativeTerms);
    final result = await _doWork(input, onError);
    if (result is ErrorResult) {
      return [];
    }
    return (result as IsolateSearchResult).searchResults;
  }

  /// [mdxPaths] narrow down which dictionary to query if provided
  Future<List<QueryResult>> query(
    String word, [
    Set<String>? mdxPaths,
    void Function(Object, StackTrace)? onError,
  ]) async {
    final input = QueryInput(word, mdxPaths);
    final result = await _doWork(input, onError);
    if (result is ErrorResult) {
      return [];
    }
    return (result as IsolateQueryResult).queryResults;
  }

  /// [mdxPath] act as a key when we want to query resource
  /// from a specific dictionary
  Future<Uint8List?> queryResource(
    String resourceUri,
    String? mdxPath, [
    void Function(Object, StackTrace)? onError,
  ]) async {
    final input = ResourceQueryInput(
      resourceUri,
      mdxPath,
    );
    final result = await _doWork(input, onError);
    if (result is ErrorResult) {
      return null;
    }
    return (result as ResourceQueryResult).resourceData;
  }

  Future<Map<String, String>> reorder(
    int oldIndex,
    int newIndex, [
    void Function(Object, StackTrace)? onError,
  ]) async {
    final input = ReOrderInput(oldIndex, newIndex);
    final result = await _doWork(input, onError);
    if (result is ErrorResult) {
      return {};
    }
    return (result as PathNameMapResult).pathNameMap;
  }

  Future<Map<String, String>> reload(
    Iterable<MdictFiles> mdictFilesList,
    String? dbPath, [
    void Function(Object, StackTrace)? onError,
  ]) async {
    final input = InitManagerInput(
      dbPath,
      mdictFilesList,
    );
    final result = await _doWork(input, onError);
    if (result is ErrorResult) {
      return {};
    }
    return (result as PathNameMapResult).pathNameMap;
  }

  /// reorder() with identical index return the same manager
  Future<Map<String, String>> getPathNameMap() => reorder(0, 0);
}
