import 'dart:io';
import 'dart:typed_data';

/// Minimal random-access file contract needed by the MDICT parser.
///
/// The parser frequently jumps between header, key block, and record block
/// offsets. Keeping this small interface lets native and web storage behave the
/// same from the parser's point of view.
abstract interface class MdictRandomAccessFile {
  /// Returns the total number of bytes in the file.
  Future<int> length();

  /// Moves the sequential read cursor to [position].
  Future<void> setPosition(int position);

  /// Reads bytes into [buffer] from the current cursor and advances the cursor.
  Future<int> readInto(Uint8List buffer);

  /// Reads [length] bytes starting at [position] without requiring callers to
  /// manage the cursor themselves.
  Future<Uint8List> read(int position, int length);

  /// Releases any resources held by the file handle.
  Future<void> close();
}

class _IoMdictRandomAccessFile implements MdictRandomAccessFile {
  _IoMdictRandomAccessFile(this._file);

  final RandomAccessFile _file;

  @override
  Future<void> close() => _file.close();

  @override
  Future<int> length() => _file.length();

  @override
  Future<int> readInto(Uint8List buffer) => _file.readInto(buffer);

  @override
  Future<Uint8List> read(int position, int length) async {
    await _file.setPosition(position);
    return _file.read(length);
  }

  @override
  Future<void> setPosition(int position) async {
    await _file.setPosition(position);
  }
}

Future<MdictRandomAccessFile> openMdictRandomAccessFile(
  String reference,
) async {
  // On native platforms a reference is just a normal file path.
  return _IoMdictRandomAccessFile(await File(reference).open());
}

/// Checks whether a native file path exists.
Future<bool> mdictFileReferenceExists(String reference) async {
  return File(reference).existsSync();
}

/// Reads all bytes from a native file path.
Future<Uint8List?> readMdictFileBytes(String reference) async {
  final file = File(reference);
  if (!file.existsSync()) return null;
  return file.readAsBytes();
}

/// Native dictionary imports copy files by path, so byte-based writes are only
/// implemented by the browser storage backend.
Future<void> writeMdictFileBytes({
  required String reference,
  required Uint8List bytes,
}) {
  throw UnsupportedError('Native mdict imports are path based.');
}

/// Deletes the file at [reference] if it exists.
Future<void> deleteMdictFileReference(String reference) async {
  final file = File(reference);
  if (file.existsSync()) {
    await file.delete();
  }
}
