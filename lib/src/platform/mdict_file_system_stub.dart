import 'dart:typed_data';
import 'package:mdict_reader/src/platform/mdict_file_system.dart';

/// Fallback stub for [IoMdictFileSystem] on non-IO platforms (e.g. Web).
class IoMdictFileSystem implements MdictFileSystem {
  /// Creates a fallback stub.
  const IoMdictFileSystem();

  @override
  Future<MdictRandomAccessFile> open(String path) {
    throw UnsupportedError('FileSystem is not supported on this platform.');
  }

  @override
  Future<bool> exists(String path) {
    throw UnsupportedError('FileSystem is not supported on this platform.');
  }

  @override
  Future<Uint8List> readAsBytes(String path) {
    throw UnsupportedError('FileSystem is not supported on this platform.');
  }
}
