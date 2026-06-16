@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:mdict_reader/src/platform/mdict_random_access_file.dart';
import 'package:test/test.dart';

void main() {
  group('MdictRandomAccessFile OPFS (Web)', () {
    const reference = 'idb://mdict/test_dict/test_file.txt';
    final testBytes = Uint8List.fromList([10, 20, 30, 40, 50, 60, 70, 80]);

    setUp(() async {
      await writeMdictFileBytes(reference: reference, bytes: testBytes);
    });

    tearDown(() async {
      await deleteMdictFileReference(reference);
    });

    test('verifies file exists and has correct length', () async {
      expect(await mdictFileReferenceExists(reference), isTrue);

      final file = await openMdictRandomAccessFile(reference);
      expect(await file.length(), equals(testBytes.length));
      await file.close();
    });

    test('reads exact byte range', () async {
      final file = await openMdictRandomAccessFile(reference);
      final readBytes = await file.read(2, 4); // should be [30, 40, 50, 60]
      expect(readBytes, equals(Uint8List.fromList([30, 40, 50, 60])));
      await file.close();
    });

    test('reads with readInto and position seek', () async {
      final file = await openMdictRandomAccessFile(reference);
      await file.setPosition(4);

      final buffer = Uint8List(3);
      final bytesRead = await file.readInto(buffer); // should read [50, 60, 70]
      expect(bytesRead, equals(3));
      expect(buffer, equals(Uint8List.fromList([50, 60, 70])));

      // Read remainder
      final buffer2 = Uint8List(3);
      final bytesRead2 = await file.readInto(buffer2); // should read [80]
      expect(bytesRead2, equals(1));
      expect(buffer2[0], equals(80));

      await file.close();
    });

    test('handles out of bounds seek/reads gracefully', () async {
      final file = await openMdictRandomAccessFile(reference);
      await file.setPosition(100);

      final buffer = Uint8List(5);
      final bytesRead = await file.readInto(buffer);
      expect(bytesRead, equals(0));

      final readBytes = await file.read(100, 10);
      expect(readBytes, isEmpty);

      await file.close();
    });

    test('deletes file successfully', () async {
      expect(await mdictFileReferenceExists(reference), isTrue);
      await deleteMdictFileReference(reference);
      expect(await mdictFileReferenceExists(reference), isFalse);
    });
  });
}
