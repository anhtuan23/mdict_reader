import 'dart:typed_data';

abstract interface class MdictRandomAccessFile {
  Future<int> length();

  Future<void> setPosition(int position);

  Future<int> readInto(Uint8List buffer);

  Future<Uint8List> read(int position, int length);

  Future<void> close();
}

// Global injectable callbacks for web/non-IO platforms.
// The caller (like mdict_flutter) registers these functions at startup.
Future<MdictRandomAccessFile> Function(String)? mdictFileOpener;
Future<bool> Function(String)? mdictFileExists;
Future<Uint8List?> Function(String)? mdictFileBytesReader;
Future<void> Function({
  required String reference,
  required Uint8List bytes,
})?
mdictFileBytesWriter;
Future<void> Function(String)? mdictFileDeleter;

Future<MdictRandomAccessFile> openMdictRandomAccessFile(
  String reference,
) async {
  final opener = mdictFileOpener;
  if (opener != null) {
    return opener(reference);
  }
  throw UnsupportedError(
    'Mdict file access is not available on this platform. '
    'Ensure you set mdictFileOpener.',
  );
}

Future<bool> mdictFileReferenceExists(String reference) async {
  final exists = mdictFileExists;
  if (exists != null) {
    return exists(reference);
  }
  return false;
}

Future<Uint8List?> readMdictFileBytes(String reference) async {
  final reader = mdictFileBytesReader;
  if (reader != null) {
    return reader(reference);
  }
  return null;
}

Future<void> writeMdictFileBytes({
  required String reference,
  required Uint8List bytes,
}) async {
  final writer = mdictFileBytesWriter;
  if (writer != null) {
    return writer(reference: reference, bytes: bytes);
  }
  throw UnsupportedError(
    'Mdict file writes are not available on this platform. '
    'Ensure you set mdictFileBytesWriter.',
  );
}

Future<void> deleteMdictFileReference(String reference) async {
  final deleter = mdictFileDeleter;
  if (deleter != null) {
    await deleter(reference);
  }
}
