import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:mdict_reader/mdict_reader.dart';
import 'package:mdict_reader/src/isolated_manager/isolated_command.dart';
import 'package:mdict_reader/src/isolated_manager/isolated_input_models.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

class IsolatedManager {
  IsolatedManager(
    this._isolateSendPort,
    this._progressStreamController,
    this._managerInitCompleter,
  );
  final SendPort _isolateSendPort;
  final Completer<void> _managerInitCompleter;
  final StreamController<MdictProgress> _progressStreamController;
  Stream<MdictProgress> get progressStream => _progressStreamController.stream;

  static Future<IsolatedManager> init(
    Iterable<MdictFiles> mdictFilesIter,
    String? dbPath, {
    CommonDatabase? db,
    MdictFileSystem? fileSystem,
  }) async {
    final progressStreamController = StreamController<MdictProgress>();
    final managerInitCompleter = Completer<void>();
    final isolateSendPort = await _initIsolate(progressStreamController);

    final manager = IsolatedManager(
      isolateSendPort,
      progressStreamController,
      managerInitCompleter,
    );

    // Asynchronously initialize the MdictManager in the worker isolate.
    unawaited(() async {
      try {
        await manager._send(InitManagerInput(dbPath, mdictFilesIter));
        managerInitCompleter.complete();
      } on Object catch (e, st) {
        managerInitCompleter.completeError(e, st);
      }
    }());

    return manager;
  }

  static Future<SendPort> _initIsolate(
    StreamController<MdictProgress> progressStreamController,
  ) async {
    final isolateSendPortCompleter = Completer<SendPort>();
    final mainReceivePort = ReceivePort()
      ..listen((dynamic data) {
        if (data is SendPort) {
          isolateSendPortCompleter.complete(data);
        } else if (data is MdictProgress) {
          progressStreamController.add(data);
        } else if (data == null) {
          unawaited(progressStreamController.close());
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
    progressStreamController.stream.listen(mainSendPort.send);
    MdictManager? manager;
    // Use an async loop (await for) to process commands sequentially.
    // This ensures only one query runs at a time within the worker isolate,
    // avoiding concurrent access errors on the persistent RandomAccessFile.
    unawaited(() async {
      await for (final dynamic data in isolateReceivePort) {
        if (data is IsolateCommand) {
          final replyPort = data.replyPort;
          final input = data.input;
          try {
            if (input is InitManagerInput) {
              final oldManager = manager;
              if (oldManager != null) {
                await oldManager.dispose();
              }
              progressStreamController.add(const MdictProgressManagerOpenDb());
              final db = input.dbPath == null
                  ? sqlite3.sqlite3.openInMemory()
                  : sqlite3.sqlite3.open(input.dbPath!);
              final newManager = await MdictManager.create(
                mdictFilesIter: input.mdictFilesIter,
                db: db,
                fileSystem: const IoMdictFileSystem(),
                progressController: progressStreamController,
              );
              manager = newManager;
              replyPort.send(newManager.pathNameMap);
            } else if (input is SearchInput) {
              final searchResult = await manager!.search(
                input.term,
                input.alternativeTerms,
              );
              replyPort.send(searchResult);
            } else if (input is QueryInput) {
              final queryResult = await manager!.query(
                input.word,
                input.mdxPaths,
              );
              replyPort.send(queryResult);
            } else if (input is ResourceQueryInput) {
              final resourceData = await manager!.queryResource(
                input.resourceUri,
                input.mdxPath,
              );
              replyPort.send(resourceData);
            } else if (input is ReOrderInput) {
              final updated = manager!.reorder(
                input.oldIndex,
                input.newIndex,
              );
              manager = updated;
              replyPort.send(updated.pathNameMap);
            }
          } on Object catch (e, stackTrace) {
            replyPort.send(IsolateError(e, stackTrace));
          }
        }
      }
    }());
  }

  Future<dynamic> _send(dynamic input) async {
    // Wait for the manager to be fully initialized, unless this is the
    // initialization command itself.
    if (input is! InitManagerInput && !_managerInitCompleter.isCompleted) {
      await _managerInitCompleter.future;
    }

    final tempPort = ReceivePort();
    _isolateSendPort.send(IsolateCommand(input, tempPort.sendPort));
    final response = await tempPort.first;
    tempPort.close();

    if (response is IsolateError) {
      throw response;
    }
    return response;
  }

  Future<List<SearchResult>> search(
    String term, [
    List<String>? alternativeTerms,
    void Function(Object, StackTrace)? onError,
  ]) async {
    try {
      final result = await _send(SearchInput(term, alternativeTerms));
      return result as List<SearchResult>;
    } on IsolateError catch (e) {
      onError?.call(e.error, e.stackTrace);
      return [];
    }
  }

  Future<List<QueryResult>> query(
    String word, [
    Set<String>? mdxPaths,
    void Function(Object, StackTrace)? onError,
  ]) async {
    try {
      final result = await _send(QueryInput(word, mdxPaths));
      return result as List<QueryResult>;
    } on IsolateError catch (e) {
      onError?.call(e.error, e.stackTrace);
      return [];
    }
  }

  Future<Uint8List?> queryResource(
    String resourceUri,
    String? mdxPath, [
    void Function(Object, StackTrace)? onError,
  ]) async {
    try {
      final result = await _send(ResourceQueryInput(resourceUri, mdxPath));
      return result as Uint8List?;
    } on IsolateError catch (e) {
      onError?.call(e.error, e.stackTrace);
      return null;
    }
  }

  Future<Map<String, String>> reorder(
    int oldIndex,
    int newIndex, [
    void Function(Object, StackTrace)? onError,
  ]) async {
    try {
      final result = await _send(ReOrderInput(oldIndex, newIndex));
      return result as Map<String, String>;
    } on IsolateError catch (e) {
      onError?.call(e.error, e.stackTrace);
      return {};
    }
  }

  Future<Map<String, String>> reload(
    Iterable<MdictFiles> mdictFilesList,
    String? dbPath, {
    void Function(Object, StackTrace)? onError,
    CommonDatabase? db,
    MdictFileSystem? fileSystem,
  }) async {
    try {
      final result = await _send(InitManagerInput(dbPath, mdictFilesList));
      return result as Map<String, String>;
    } on IsolateError catch (e) {
      onError?.call(e.error, e.stackTrace);
      return {};
    }
  }

  /// reorder() with identical index returns the same manager
  Future<Map<String, String>> getPathNameMap() => reorder(0, 0);
}
