import 'dart:io';
import 'dart:typed_data';
import 'package:mdict_reader/src/platform/mdict_file_system.dart';

/// Native VM implementation of [MdictRandomAccessFile] wrapping a
/// [RandomAccessFile].
class IoMdictRandomAccessFile implements MdictRandomAccessFile {
  /// Creates a new [IoMdictRandomAccessFile] wrapping a [RandomAccessFile].
  IoMdictRandomAccessFile(this._file);

  final RandomAccessFile _file;

  @override
  Future<void> close() => _file.close();

  @override
  Future<int> length() => _file.length();

  @override
  Future<Uint8List> read(int position, int length) async {
    await _file.setPosition(position);
    return _file.read(length);
  }

  @override
  Future<int> readInto(Uint8List buffer) => _file.readInto(buffer);

  @override
  Future<void> setPosition(int position) => _file.setPosition(position);
}

/// Native VM implementation of [MdictFileSystem] using `dart:io`.
class IoMdictFileSystem implements MdictFileSystem {
  /// Creates a native VM [IoMdictFileSystem].
  const IoMdictFileSystem();

  @override
  Future<MdictRandomAccessFile> open(String path) async {
    final file = await File(path).open();
    return IoMdictRandomAccessFile(file);
  }

  @override
  Future<bool> exists(String path) => Future.value(File(path).existsSync());

  @override
  Future<Uint8List> readAsBytes(String path) => File(path).readAsBytes();
}
