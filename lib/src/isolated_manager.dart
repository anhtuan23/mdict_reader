import 'dart:async';
import 'dart:isolate';

import 'package:mdict_reader/src/isolated_models.dart';

import '../mdict_reader.dart';

class IsolatedManager {
  IsolatedManager(this.toIsolateSender, this.resultStreamController);

  final SendPort toIsolateSender;
  final StreamController<dynamic> resultStreamController;

  // Stream<dynamic> get resultStream => resultStreamController.broadcast();

  static Completer<Null>? managerInitializedCompleter = Completer<Null>();

  static Future<IsolatedManager> init(List<String> pathList) async {
    final _resultStreamController = StreamController<dynamic>.broadcast();

    final toIsolateSendPort = await _initIsolate(_resultStreamController);

    /// Begin to create manager right away
    final input = InitManagerInput(pathList);
    toIsolateSendPort.send(input);

    return IsolatedManager(
      toIsolateSendPort,
      _resultStreamController,
    );
  }

  static Future<SendPort> _initIsolate(
    StreamController<dynamic> resultStreamController,
  ) async {
    final completer = Completer<SendPort>();
    final isolateToMainStream = ReceivePort();

    isolateToMainStream.listen((data) {
      if (data is SendPort) {
        final mainToIsolateStream = data;
        completer.complete(mainToIsolateStream);
      }

      /// On initial init a [PathNameMapResult] will be returned
      /// use this value to mark completer as completed
      /// data is PathNameMapResult means manager is initialized
      else if (data is PathNameMapResult &&
          managerInitializedCompleter != null) {
        managerInitializedCompleter?.complete();
        managerInitializedCompleter = null;
      } else {
        resultStreamController.add(data);
      }
    });

    await Isolate.spawn(_myIsolate, isolateToMainStream.sendPort);
    return completer.future;
  }

  static void _myIsolate(SendPort isolateToMainStream) {
    final mainToIsolateStream = ReceivePort();
    isolateToMainStream.send(mainToIsolateStream.sendPort);

    MdictManager? manager;

    mainToIsolateStream.listen((data) async {
      // First data is mdict paths to init dictionary
      if (data is InitManagerInput) {
        manager = await MdictManager.create(data.pathList);
        isolateToMainStream
            .send(PathNameMapResult(data.hashCode, manager!.pathNameMap));
      } else if (data is SearchInput) {
        final searchResult = await manager!.search(data.term);
        isolateToMainStream.send(SearchResult(data.hashCode, searchResult));
      } else if (data is QueryInput) {
        final queryResult = await manager!.query(data.word);
        isolateToMainStream.send(QueryResult(data.hashCode, queryResult));
      } else if (data is ReOrderInput) {
        manager = manager!.reOrder(data.oldIndex, data.newIndex);
        isolateToMainStream
            .send(PathNameMapResult(data.hashCode, manager!.pathNameMap));
      }
    });
  }

  Future<Result> _doWork<I>(I input) async {
    final _completer = managerInitializedCompleter;
    if (_completer != null) {
      await _completer.future;
      return _doWork(input);
    } else {
      toIsolateSender.send(input);

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

  Future<Map<String, String>> query(String word) async {
    final input = QueryInput(word);
    final result = await _doWork(input);
    return (result as QueryResult).queryResult;
  }

  Future<Map<String, String>> reOrder(int oldIndex, int newIndex) async {
    final input = ReOrderInput(oldIndex, newIndex);
    final result = await _doWork(input);
    return (result as PathNameMapResult).pathNamePath;
  }

  Future<Map<String, String>> reload(List<String> pathList) async {
    final input = InitManagerInput(pathList);
    final result = await _doWork(input);
    return (result as PathNameMapResult).pathNamePath;
  }

  /// reOrder() with identical index return the same manager
  Future<Map<String, String>> getPathNameMap() => reOrder(0, 0);
}
