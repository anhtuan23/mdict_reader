import 'dart:typed_data';

export 'mdict_file_system_stub.dart'
    if (dart.library.io) 'mdict_file_system_io.dart';

/// Exposes the same random-access file API on all platforms.
abstract interface class MdictRandomAccessFile {
  /// Returns the length of the file in bytes.
  Future<int> length();

  /// Sets the current read position in the file.
  Future<void> setPosition(int position);

  /// Reads bytes from the current position into the provided buffer.
  /// Returns the number of bytes read (0 if end-of-file is reached).
  Future<int> readInto(Uint8List buffer);

  /// Reads a chunk of [length] bytes starting at [position].
  Future<Uint8List> read(int position, int length);

  /// Closes the file and releases any associated resources.
  Future<void> close();
}

/// Abstract read-only filesystem contract for accessing dictionary files.
abstract interface class MdictFileSystem {
  /// Opens a random-access file handle for the dictionary at [path].
  Future<MdictRandomAccessFile> open(String path);

  /// Checks if a file exists at the given [path].
  Future<bool> exists(String path);

  /// Reads the entire contents of the file at [path] as bytes.
  Future<Uint8List> readAsBytes(String path);
}
