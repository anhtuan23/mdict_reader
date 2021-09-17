import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/isolated_models.dart';

class IsolatedManager {
  IsolatedManager(
    this.isolateSendPort,
    this.resultStreamController,
    this.managerInitCompleter,
  );

  final SendPort isolateSendPort;
  final StreamController<dynamic> resultStreamController;

  final Completer<void> managerInitCompleter;

  static Future<IsolatedManager> init(
      Iterable<MdictFiles> mdictFilesIter) async {
    final _resultStreamController = StreamController<dynamic>.broadcast();
    final managerInitCompleter = Completer<void>();

    final isolateSendPort =
        await _initIsolate(_resultStreamController, managerInitCompleter);

    /// Begin to create manager right away
    final input = InitManagerInput(mdictFilesIter);
    isolateSendPort.send(input);

    return IsolatedManager(
      isolateSendPort,
      _resultStreamController,
      managerInitCompleter,
    );
  }

  static Future<SendPort> _initIsolate(
    StreamController<dynamic> resultStreamController,
    Completer<void> managerInitCompleter,
  ) async {
    final isolateSendPortCompleter = Completer<SendPort>();
    final mainReceivePort = ReceivePort();

    mainReceivePort.listen((data) {
      if (data is SendPort) {
        isolateSendPortCompleter.complete(data);
      }

      /// On initial init a [PathNameMapResult] will be returned
      /// use this value to mark completer as completed
      /// Data is PathNameMapResult means manager is initialized
      else if (data is PathNameMapResult && !managerInitCompleter.isCompleted) {
        managerInitCompleter.complete();
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

    late MdictManager manager;

    isolateReceivePort.listen((data) async {
      // First data is mdict paths to init dictionary
      if (data is InitManagerInput) {
        manager = await MdictManager.create(data.mdictFilesIter);
        mainSendPort.send(
          PathNameMapResult(data.hashCode, manager.pathNameMap),
        );
      } else if (data is SearchInput) {
        final searchReturnList = await manager.search(data.term);
        mainSendPort.send(SearchResult(data.hashCode, searchReturnList));
      } else if (data is QueryInput) {
        final queryResult = await manager.query(data.word);
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
    if (!managerInitCompleter.isCompleted) {
      await managerInitCompleter.future;
      return _doWork(input);
    } else {
      isolateSendPort.send(input);

      final completer = Completer<Result>();
      StreamSubscription? streamSubscription;
      streamSubscription =
          resultStreamController.stream.listen((dynamic result) {
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

  Future<List<QueryReturn>> query(String word) async {
    final input = QueryInput(word);
    final result = await _doWork(input);
    return (result as QueryResult).queryReturns;
  }

  /// [mdxPath] act as a key when we want to query resource from a specific dictionary
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
      Iterable<MdictFiles> mdictFilesList) async {
    final input = InitManagerInput(mdictFilesList);
    final result = await _doWork(input);
    return (result as PathNameMapResult).pathNamePath;
  }

  /// reOrder() with identical index return the same manager
  Future<Map<String, String>> getPathNameMap() => reOrder(0, 0);
}
