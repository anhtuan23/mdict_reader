import 'dart:typed_data';

abstract interface class MdictRandomAccessFile {
  Future<int> length();

  Future<void> setPosition(int position);

  Future<int> readInto(Uint8List buffer);

  Future<Uint8List> read(int position, int length);

  Future<void> close();
}

Future<MdictRandomAccessFile> openMdictRandomAccessFile(String reference) {
  throw UnsupportedError(
    'Mdict file access is not available on this platform.',
  );
}

Future<bool> mdictFileReferenceExists(String reference) async => false;

Future<Uint8List?> readMdictFileBytes(String reference) async => null;

Future<void> writeMdictFileBytes({
  required String reference,
  required Uint8List bytes,
}) {
  throw UnsupportedError(
    'Mdict file writes are not available on this platform.',
  );
}

Future<void> deleteMdictFileReference(String reference) async {}
