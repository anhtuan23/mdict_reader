import 'dart:async';
import 'dart:isolate';

import 'package:mdict_reader/src/isolated_models.dart';

import '../mdict_reader.dart';

class IsolatedManager {
  IsolatedManager(this.isolateSendPort, this.resultStreamController);

  final SendPort isolateSendPort;
  final StreamController<dynamic> resultStreamController;

  static Completer<void>? managerInitCompleter = Completer<void>();

  static Future<IsolatedManager> init(List<MdictFiles> mdictFilesList) async {
    final _resultStreamController = StreamController<dynamic>.broadcast();

    final isolateSendPort = await _initIsolate(_resultStreamController);

    /// Begin to create manager right away
    final input = InitManagerInput(mdictFilesList);
    isolateSendPort.send(input);

    return IsolatedManager(
      isolateSendPort,
      _resultStreamController,
    );
  }

  static Future<SendPort> _initIsolate(
    StreamController<dynamic> resultStreamController,
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
      else if (data is PathNameMapResult && managerInitCompleter != null) {
        managerInitCompleter?.complete();
        managerInitCompleter = null;
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
        manager = await MdictManager.create(data.mdictFilesList);
        mainSendPort
            .send(PathNameMapResult(data.hashCode, manager.pathNameMap));
      } else if (data is SearchInput) {
        final searchResult = await manager.search(data.term);
        mainSendPort.send(SearchResult(data.hashCode, searchResult));
      } else if (data is QueryInput) {
        final queryResult = await manager.query(data.word);
        mainSendPort.send(QueryResult(data.hashCode, queryResult));
      } else if (data is ReOrderInput) {
        manager = manager.reOrder(data.oldIndex, data.newIndex);
        mainSendPort
            .send(PathNameMapResult(data.hashCode, manager.pathNameMap));
      }
    });
  }

  Future<Result> _doWork<I>(I input) async {
    final _completer = managerInitCompleter;
    if (_completer != null) {
      await _completer.future;
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

  Future<Map<String, List<String>>> search(String term) async {
    final input = SearchInput(term);
    final result = await _doWork(input);
    return (result as SearchResult).searchResult;
  }

  Future<List<QueryReturn>> query(String word) async {
    final input = QueryInput(word);
    final result = await _doWork(input);
    return (result as QueryResult).queryReturns;
  }

  Future<Map<String, String>> reOrder(int oldIndex, int newIndex) async {
    final input = ReOrderInput(oldIndex, newIndex);
    final result = await _doWork(input);
    return (result as PathNameMapResult).pathNamePath;
  }

  Future<Map<String, String>> reload(List<MdictFiles> mdictFilesList) async {
    final input = InitManagerInput(mdictFilesList);
    final result = await _doWork(input);
    return (result as PathNameMapResult).pathNamePath;
  }

  /// reOrder() with identical index return the same manager
  Future<Map<String, String>> getPathNameMap() => reOrder(0, 0);
}
