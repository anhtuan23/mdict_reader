import 'dart:async';
import 'dart:typed_data';

import 'package:mdict_reader/mdict_reader.dart';

/// Web implementation of the public [IsolatedManager] API.
///
/// The native implementation runs `MdictManager` inside a Dart isolate so heavy
/// indexing and queries do not block the UI isolate. On web, the app is already
/// constrained by browser storage and sqlite3 WASM. Keeping the same public API
/// but running in the current isolate lets Flutter web compile while preserving
/// the call sites in the app.
class IsolatedManager {
  IsolatedManager._(this._manager, this._progressStreamController);

  MdictManager _manager;
  final StreamController<MdictProgress> _progressStreamController;

  /// Progress emitted while dictionaries are indexed or reloaded.
  Stream<MdictProgress> get progressStream => _progressStreamController.stream;

  /// Creates a manager from the supplied MDX/MDD/CSS references and SQLite path.
  static Future<IsolatedManager> init(
    Iterable<MdictFiles> mdictFilesIter,
    String? dbPath,
  ) async {
    final progressStreamController = StreamController<MdictProgress>();
    final manager = await MdictManager.create(
      mdictFilesIter: mdictFilesIter,
      dbPath: dbPath,
      progressController: progressStreamController,
    );
    return IsolatedManager._(manager, progressStreamController);
  }

  Future<List<SearchReturn>> search(
    String term, [
    void Function(Object, StackTrace)? onError,
  ]) async {
    // Keep web behavior aligned with native: report errors through the optional
    // callback and return an empty result instead of throwing through UI code.
    try {
      return _manager.search(term);
    } on Object catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      return [];
    }
  }

  Future<List<QueryReturn>> query(
    String word, [
    Set<String>? mdxPaths,
    void Function(Object, StackTrace)? onError,
  ]) async {
    try {
      return _manager.query(word, mdxPaths);
    } on Object catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      return [];
    }
  }

  Future<Uint8List?> queryResource(
    String resourceUri,
    String? mdxPath, [
    void Function(Object, StackTrace)? onError,
  ]) async {
    try {
      return _manager.queryResource(resourceUri, mdxPath);
    } on Object catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      return null;
    }
  }

  Future<Map<String, String>> reorder(
    int oldIndex,
    int newIndex, [
    void Function(Object, StackTrace)? onError,
  ]) async {
    try {
      _manager = _manager.reorder(oldIndex, newIndex);
      return _manager.pathNameMap;
    } on Object catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      return {};
    }
  }

  Future<Map<String, String>> reload(
    Iterable<MdictFiles> mdictFilesList,
    String? dbPath, [
    void Function(Object, StackTrace)? onError,
  ]) async {
    try {
      // Recreate the manager so the SQLite index and path-name map reflect the
      // latest browser imports or deletes.
      _manager = await MdictManager.create(
        mdictFilesIter: mdictFilesList,
        dbPath: dbPath,
        progressController: _progressStreamController,
      );
      return _manager.pathNameMap;
    } on Object catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      return {};
    }
  }

  /// Returns the current mapping of MDX reference to dictionary display name.
  Future<Map<String, String>> getPathNameMap() async => _manager.pathNameMap;
}
