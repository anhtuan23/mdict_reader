import 'dart:math' as math;
import 'dart:typed_data';

import 'package:idb_shim/idb_browser.dart' as idb;

/// Minimal random-access file contract needed by the MDICT parser.
///
/// In the browser this interface is backed by an in-memory byte list loaded
/// from IndexedDB. It intentionally mirrors the native `RandomAccessFile`
/// operations used by the parser.
abstract interface class MdictRandomAccessFile {
  /// Returns the total number of bytes in the stored file.
  Future<int> length();

  /// Moves the sequential read cursor to [position].
  Future<void> setPosition(int position);

  /// Reads bytes into [buffer] from the current cursor and advances the cursor.
  Future<int> readInto(Uint8List buffer);

  /// Reads [length] bytes starting at [position].
  Future<Uint8List> read(int position, int length);

  /// Closes the file handle. Web bytes are already in memory, so this is a
  /// no-op kept for API symmetry with native files.
  Future<void> close();
}

class _WebMdictRandomAccessFile implements MdictRandomAccessFile {
  _WebMdictRandomAccessFile(this._bytes);

  final Uint8List _bytes;
  int _position = 0;

  @override
  Future<void> close() async {}

  @override
  Future<int> length() async => _bytes.length;

  @override
  Future<int> readInto(Uint8List buffer) async {
    if (_position >= _bytes.length) return 0;
    final readable = math.min(buffer.length, _bytes.length - _position);
    buffer.setRange(0, readable, _bytes, _position);
    _position += readable;
    return readable;
  }

  @override
  Future<Uint8List> read(int position, int length) async {
    final end = math.min(position + length, _bytes.length);
    return Uint8List.sublistView(_bytes, position, end);
  }

  @override
  Future<void> setPosition(int position) async {
    _position = math.min(math.max(position, 0), _bytes.length);
  }
}

const _dbName = 'readdict_mdict_files';
const _storeName = 'files';

Future<idb.Database>? _databaseFuture;

Future<idb.Database> _database() {
  // Keep the IndexedDB connection shared. Opening IndexedDB is asynchronous and
  // browser-backed, so repeated opens would add unnecessary latency.
  return _databaseFuture ??= idb.getIdbFactory()!.open(
    _dbName,
    version: 1,
    onUpgradeNeeded: (event) {
      final database = (event.target as idb.OpenDBRequest).result;
      if (!database.objectStoreNames.contains(_storeName)) {
        database.createObjectStore(_storeName);
      }
    },
  );
}

idb.ObjectStore _store(idb.Database database, String mode) {
  return database.transaction(_storeName, mode).objectStore(_storeName);
}

Uint8List _asBytes(Object value) {
  // Different browser engines can deserialize IndexedDB byte values as either a
  // Uint8List or a plain List<int>. Normalize both shapes for the parser.
  if (value is Uint8List) return value;
  if (value is List<int>) return Uint8List.fromList(value);
  throw StateError('Unsupported mdict file payload: ${value.runtimeType}');
}

Future<MdictRandomAccessFile> openMdictRandomAccessFile(
  String reference,
) async {
  // A web "file path" is a logical key. The app writes selected browser file
  // bytes into IndexedDB under this key before mdict_reader tries to open it.
  final bytes = await readMdictFileBytes(reference);
  if (bytes == null) {
    throw StateError('Mdict file reference does not exist: $reference');
  }
  return _WebMdictRandomAccessFile(bytes);
}

Future<bool> mdictFileReferenceExists(String reference) async {
  final database = await _database();
  final key = await _store(database, idb.idbModeReadOnly).getKey(reference);
  return key != null;
}

/// Reads the full byte payload stored under [reference], or `null` if the
/// browser has no such dictionary file.
Future<Uint8List?> readMdictFileBytes(String reference) async {
  final database = await _database();
  final value =
      await _store(database, idb.idbModeReadOnly).getObject(reference);
  if (value == null) return null;
  return _asBytes(value);
}

Future<void> writeMdictFileBytes({
  required String reference,
  required Uint8List bytes,
}) async {
  // Store the original selected-file bytes. The MDICT parser needs random
  // access to the exact binary content, so text encodings are not involved.
  final database = await _database();
  await _store(database, idb.idbModeReadWrite).put(bytes, reference);
}

/// Removes the dictionary byte payload stored under [reference].
Future<void> deleteMdictFileReference(String reference) async {
  final database = await _database();
  await _store(database, idb.idbModeReadWrite).delete(reference);
}
