part of 'mdict_reader.dart';

abstract class MdictReaderHelper {
  static InputStream _decompressBlock(Uint8List compBlock) {
    final flag = compBlock[0];
    final data = compBlock.sublist(8);
    if (flag == 2) {
      return BytesInputStream(zlib.decoder.convert(data) as Uint8List);
    } else {
      return BytesInputStream(data);
    }
  }

  static void _decryptBlock(Uint8List key, Uint8List data, int offset) {
    var previous = 0x36;
    for (var i = 0; i < data.length - offset; i++) {
      var t = (data[i + offset] >> 4 | data[i + offset] << 4) & 0xff;
      t = t ^ previous ^ (i & 0xff) ^ key[i % key.length];
      previous = data[i + offset];
      data[i + offset] = t;
    }
  }

  static Uint8List _computeKey(Uint8List data) {
    final ripemd128 = Digest('RIPEMD-128')
      ..update(data, 4, 4)
      ..update(Uint8List.fromList(const <int>[0x95, 0x36, 0x00, 0x00]), 0, 4);
    final key = Uint8List(16);
    ripemd128.doFinal(key, 0);
    return key;
  }

  static Future<List<MdictKey>> _readKeys(
    FileInputStream fileInputStream,
    Map<String, String> header,
  ) async {
    final encrypted = header['encrypted'] == '2';
    final utf8 = header['encoding'] == 'UTF-8';
    final keyNumBlocks = await fileInputStream.readUint64();
    // ignore: unused_local_variable
    final keyNumEntries = await fileInputStream.readUint64();
    // ignore: unused_local_variable
    final keyIndexDecompLen = await fileInputStream.readUint64();
    final keyIndexCompLen = await fileInputStream.readUint64();
    // ignore: unused_local_variable
    final keyBlocksLen = await fileInputStream.readUint64();
    await fileInputStream.skip(4);
    final compSize = List.filled(keyNumBlocks, -1);
    final decompSize = List.filled(keyNumBlocks, -1);
    final numEntries = List.filled(keyNumBlocks, -1);
    final indexCompBlock = await fileInputStream.readBytes(keyIndexCompLen);
    if (encrypted) {
      final key = _computeKey(indexCompBlock);
      _decryptBlock(key, indexCompBlock, 8);
    }
    final indexDs = _decompressBlock(indexCompBlock);
    for (var i = 0; i < keyNumBlocks; i++) {
      numEntries[i] = await indexDs.readUint64();
      var firstLength = (await indexDs.readUint16()) + 1;
      if (!utf8) {
        firstLength = firstLength * 2;
      }
      // ignore: unused_local_variable
      final firstWord = await indexDs.readString(size: firstLength, utf8: utf8);
      var lastLength = (await indexDs.readUint16()) + 1;
      if (!utf8) {
        lastLength = lastLength * 2;
      }
      // print('Last length: $last_length\n utf8: $utf8\n\n');
      // ignore: unused_local_variable
      final lastWord = await indexDs.readString(size: lastLength, utf8: utf8);
      compSize[i] = await indexDs.readUint64();
      decompSize[i] = await indexDs.readUint64();
    }
    final keyList = <MdictKey>[];
    for (var i = 0; i < keyNumBlocks; i++) {
      final keyCompBlock = await fileInputStream.readBytes(compSize[i]);
      final blockIn = _decompressBlock(keyCompBlock);
      for (var j = 0; j < numEntries[i]; j++) {
        final offset = await blockIn.readUint64();
        final word = await blockIn.readString(utf8: utf8);
        if (keyList.isNotEmpty) {
          keyList[keyList.length - 1].length =
              offset - keyList[keyList.length - 1].offset;
        }
        keyList.add(MdictKey(word, offset));
      }
    }
    return keyList;
  }

  /// Return 2 Init32List of compressedRecordSize and uncompressedRecordSize
  static Future<List<Uint32List>> _readRecords(
    FileInputStream fileInputStream,
  ) async {
    final recordNumBlocks = await fileInputStream.readUint64();
    // ignore: unused_local_variable
    final recordNumEntries = await fileInputStream.readUint64();
    // ignore: unused_local_variable
    final recordIndexLen = await fileInputStream.readUint64();
    // ignore: unused_local_variable
    final recordBlocksLen = await fileInputStream.readUint64();
    final compressedSize = Uint32List(recordNumBlocks);
    final uncompressedSize = Uint32List(recordNumBlocks);
    for (var i = 0; i < recordNumBlocks; i++) {
      compressedSize[i] = await fileInputStream.readUint64();
      uncompressedSize[i] = await fileInputStream.readUint64();
    }
    return [compressedSize, uncompressedSize];
  }

  static Map<String, String> _parseHeader(String header) {
    final attributes = <String, String>{};
    final doc = parseFragment(header);
    for (final entry in doc.nodes.first.attributes.entries) {
      attributes[entry.key.toString()] = entry.value;
    }
    return attributes;
  }

  static Future<Map<String, String>> _readHeader(
    FileInputStream fileInputStream,
  ) async {
    final headerLength = await fileInputStream.readUint32();
    final header =
        await fileInputStream.readString(size: headerLength, utf8: false);
    await fileInputStream.skip(4);
    return _parseHeader(header);
  }

  /// Find urls in css
  /// Ex: url(icon-plus-minus-orange.png)
  /// Explaination: regexr.com/6niqg
  static Iterable<RegExpMatch> cssUrlExtractor(String input) {
    final exp = RegExp(r"(?<=url\()[^'].+(?=\))");
    return exp.allMatches(input);
  }
}
