import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// JS TypedArray interop to construct a Uint8Array wrapping an ArrayBuffer.
///
/// In JavaScript, raw binary data in files is accessed via `ArrayBuffer`
/// objects. To read or manipulate these bytes in Dart/JavaScript, we wrap
/// the buffer in a `Uint8Array` view. We define this extension type so we
/// can call the JavaScript constructor `new Uint8Array(buffer)` directly
/// from Dart.
@JS('Uint8Array')
extension type Uint8Array._(JSObject _) implements JSObject {
  /// Constructs a JavaScript `Uint8Array` wrapper around the given [buffer].
  external Uint8Array(JSObject buffer);
}

/// Minimal random-access file contract needed by the MDICT parser.
///
/// This mimics the native `RandomAccessFile` interface. It allows the parser
/// to read specific bytes at arbitrary offsets (seeking) without reading the
/// entire dictionary into RAM.
abstract interface class MdictRandomAccessFile {
  /// Returns the total number of bytes in the stored file.
  Future<int> length();

  /// Moves the sequential read cursor to [position].
  Future<void> setPosition(int position);

  /// Reads bytes into [buffer] from the current cursor and advances the cursor.
  Future<int> readInto(Uint8List buffer);

  /// Reads [length] bytes starting at [position].
  Future<Uint8List> read(int position, int length);

  /// Closes the file handle.
  Future<void> close();
}

/// Web implementation of [MdictRandomAccessFile] using the **Origin Private
/// File System (OPFS)**.
///
/// Instead of holding the entire file payload in memory, this class holds a
/// lightweight [web.FileSystemFileHandle] reference. Reads slice the file
/// on-demand using the browser's native filesystem, ensuring low memory usage
/// even for multi-gigabyte dictionary files.
class _WebMdictRandomAccessFile implements MdictRandomAccessFile {
  _WebMdictRandomAccessFile(this._fileHandle);

  final web.FileSystemFileHandle _fileHandle;
  int _position = 0;

  @override
  Future<void> close() async {}

  @override
  Future<int> length() async {
    // getFile() retrieves a File object containing metadata like size.
    final file = await _fileHandle.getFile().toDart;
    return file.size;
  }

  @override
  Future<int> readInto(Uint8List buffer) async {
    final file = await _fileHandle.getFile().toDart;
    final size = file.size;
    if (_position >= size) return 0;

    // Determine how many bytes we can actually read up to the end of the file.
    final readLength = math.min(buffer.length, size - _position);
    
    // Slice a portion of the file asynchronously.
    final slice = file.slice(_position, _position + readLength);
    final arrayBuffer = await slice.arrayBuffer().toDart;
    
    // Convert JS ArrayBuffer to a JSUint8Array view, and then to a Dart
    // Uint8List.
    final uint8Array = Uint8Array(arrayBuffer);
    final readBytes = (uint8Array as JSUint8Array).toDart;

    // Copy the read bytes into the user's destination buffer.
    buffer.setRange(0, readBytes.length, readBytes);
    _position += readBytes.length;
    return readBytes.length;
  }

  @override
  Future<Uint8List> read(int position, int length) async {
    final file = await _fileHandle.getFile().toDart;
    final size = file.size;
    if (position >= size) return Uint8List(0);

    // Slice a portion of the file asynchronously.
    final end = math.min(position + length, size);
    final slice = file.slice(position, end);
    final arrayBuffer = await slice.arrayBuffer().toDart;
    
    // Convert JS ArrayBuffer to JSUint8Array, and then to a Dart Uint8List.
    final uint8Array = Uint8Array(arrayBuffer);
    return (uint8Array as JSUint8Array).toDart;
  }

  @override
  Future<void> setPosition(int position) async {
    _position = position;
  }
}

/// Resolves a reference path to an OPFS file handle, traversing directories.
///
/// References are formulated as `idb://mdict/dict_name/file_name` for backward
/// compatibility. Slashes `/` indicate subdirectories.
/// If [create] is true, folders and the final file will be created if missing.
Future<web.FileSystemFileHandle> _getFileHandle(
  String reference, {
  bool create = false,
}) async {
  var path = reference;
  const prefix = 'idb://mdict/';
  if (path.startsWith(prefix)) {
    path = path.substring(prefix.length);
  }

  // Get directory handle for the root of the OPFS storage.
  final storage = web.window.navigator.storage;
  var dir = await storage.getDirectory().toDart;

  // Split reference parts to traverse nested directories.
  final parts = path.split('/');
  if (parts.length > 1) {
    for (var i = 0; i < parts.length - 1; i++) {
      dir = await dir.getDirectoryHandle(
        parts[i],
        web.FileSystemGetDirectoryOptions(create: create),
      ).toDart;
    }
  }

  // Return the final file handle inside the target directory.
  return dir.getFileHandle(
    parts.last,
    web.FileSystemGetFileOptions(create: create),
  ).toDart;
}

/// Helper method to delete a file or directory recursively from OPFS.
Future<void> _deleteEntry(String reference) async {
  var path = reference;
  const prefix = 'idb://mdict/';
  if (path.startsWith(prefix)) {
    path = path.substring(prefix.length);
  }

  final storage = web.window.navigator.storage;
  var dir = await storage.getDirectory().toDart;

  final parts = path.split('/');
  if (parts.length > 1) {
    for (var i = 0; i < parts.length - 1; i++) {
      try {
        dir = await dir.getDirectoryHandle(
          parts[i],
          web.FileSystemGetDirectoryOptions(create: false),
        ).toDart;
      } on Object catch (_) {
        return; // Directory does not exist, nothing to delete
      }
    }
  }

  try {
    // removeEntry deletes a file or directory recursively.
    await dir.removeEntry(
      parts.last,
      web.FileSystemRemoveOptions(recursive: true),
    ).toDart;
  } on Object catch (_) {
    // Ignore error if target file or folder does not exist
  }
}

/// Helper method to check if a file exists in OPFS.
Future<bool> _fileExists(String reference) async {
  try {
    await _getFileHandle(reference);
    return true;
  } on Object catch (_) {
    return false;
  }
}

/// Opens the MDICT file reference at [reference].
Future<MdictRandomAccessFile> openMdictRandomAccessFile(
  String reference,
) async {
  final fileHandle = await _getFileHandle(reference);
  return _WebMdictRandomAccessFile(fileHandle);
}

/// Checks if [reference] exists in browser storage.
Future<bool> mdictFileReferenceExists(String reference) async {
  return _fileExists(reference);
}

/// Reads the full byte payload stored under [reference], or `null` if
/// not found.
Future<Uint8List?> readMdictFileBytes(String reference) async {
  try {
    final fileHandle = await _getFileHandle(reference);
    final file = await fileHandle.getFile().toDart;
    final arrayBuffer = await file.arrayBuffer().toDart;
    final uint8Array = Uint8Array(arrayBuffer);
    return (uint8Array as JSUint8Array).toDart;
  } on Object catch (_) {
    return null;
  }
}

/// Writes the [bytes] payload stored under [reference].
Future<void> writeMdictFileBytes({
  required String reference,
  required Uint8List bytes,
}) async {
  final fileHandle = await _getFileHandle(reference, create: true);
  final writable = await fileHandle.createWritable().toDart;
  
  // Write bytes payload using JavaScript Uint8Array representation.
  await writable.write(bytes.toJS).toDart;
  await writable.close().toDart;
}

/// Removes the dictionary byte payload stored under [reference].
Future<void> deleteMdictFileReference(String reference) async {
  await _deleteEntry(reference);
}
