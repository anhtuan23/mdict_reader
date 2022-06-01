import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/isolated_manager/isolated_models.dart';

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
    final _resultStreamController = StreamController<dynamic>.broadcast();
    final _progressStreamController = StreamController<MdictProgress>();
    final managerInitCompleter = Completer<void>();

    final isolateSendPort = await _initIsolate(
      _resultStreamController,
      _progressStreamController,
      managerInitCompleter,
    );

    /// Begin to create manager right away
    final input = InitManagerInput(dbPath, mdictFilesIter);
    isolateSendPort.send(input);

    return IsolatedManager(
      isolateSendPort,
      _resultStreamController,
      _progressStreamController,
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
        } else {
          resultStreamController.add(data);
        }
      });

    await Isolate.spawn(_myIsolate, mainReceivePort.sendPort);
    return isolateSendPortCompleter.future;
  }

  static void _myIsolate(SendPort mainSendPort) {
    final isolateReceivePort = ReceivePort();
    mainSendPort.send(isolateReceivePort.sendPort);

    final progressStreamController = StreamController<MdictProgress>();
    progressStreamController.stream.listen(mainSendPort.send);

    late MdictManager manager;

    isolateReceivePort.listen((dynamic data) async {
      // First data is mdict paths to init dictionary
      if (data is InitManagerInput) {
        manager = await MdictManager.create(
          mdictFilesIter: data.mdictFilesIter,
          dbPath: data.dbPath,
          progressController: progressStreamController,
        );
        mainSendPort.send(
          PathNameMapResult(data.hashCode, manager.pathNameMap),
        );
      } else if (data is SearchInput) {
        final searchReturnList = await manager.search(data.term);
        mainSendPort.send(SearchResult(data.hashCode, searchReturnList));
      } else if (data is QueryInput) {
        final queryResult = await manager.query(data.word, data.mdxPaths);
        mainSendPort.send(
          QueryResult(data.hashCode, queryResult),
        );
      } else if (data is ResourceQueryInput) {
        final resourceData = await manager.queryResource(
          data.resourceUri,
          data.mdxPath,
        );
        mainSendPort.send(
          ResourceQueryResult(data.hashCode, resourceData),
        );
      } else if (data is ReOrderInput) {
        manager = manager.reOrder(data.oldIndex, data.newIndex);
        mainSendPort.send(
          PathNameMapResult(data.hashCode, manager.pathNameMap),
        );
      }
    });
  }

  Future<Result> _doWork<I>(I input) async {
    if (!_managerInitCompleter.isCompleted) {
      await _managerInitCompleter.future;
      return _doWork(input);
    } else {
      _isolateSendPort.send(input);

      final completer = Completer<Result>();
      StreamSubscription? streamSubscription;
      streamSubscription =
          _resultStreamController.stream.listen((dynamic result) {
        if (result is Result && result.inputHashCode == input.hashCode) {
          completer.complete(result);
          streamSubscription?.cancel();
        }
      });
      return completer.future;
    }
  }

  Future<List<SearchReturn>> search(String term) async {
    final input = SearchInput(term);
    final result = await _doWork(input);
    return (result as SearchResult).searchReturnList;
  }

  /// [mdxPaths] narrow down which dictionary to query if provided
  Future<List<QueryReturn>> query(String word, [Set<String>? mdxPaths]) async {
    final input = QueryInput(word, mdxPaths);
    final result = await _doWork(input);
    return (result as QueryResult).queryReturns;
  }

  /// [mdxPath] act as a key when we want to query resource
  /// from a specific dictionary
  Future<Uint8List?> queryResource(String resourceUri, String? mdxPath) async {
    final input = ResourceQueryInput(resourceUri, mdxPath);
    final result = await _doWork(input);
    return (result as ResourceQueryResult).resourceData;
  }

  Future<Map<String, String>> reOrder(int oldIndex, int newIndex) async {
    final input = ReOrderInput(oldIndex, newIndex);
    final result = await _doWork(input);
    return (result as PathNameMapResult).pathNamePath;
  }

  Future<Map<String, String>> reload(
    Iterable<MdictFiles> mdictFilesList,
    String? dbPath,
  ) async {
    final input = InitManagerInput(
      dbPath,
      mdictFilesList,
    );
    final result = await _doWork(input);
    return (result as PathNameMapResult).pathNamePath;
  }

  /// reOrder() with identical index return the same manager
  Future<Map<String, String>> getPathNameMap() => reOrder(0, 0);
}
