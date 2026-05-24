part of 'mdict_reader.dart';

abstract class MdictReaderHelper {
  static InputStream _decompressBlock(Uint8List compBlock) {
    final flag = compBlock[0];
    final data = compBlock.sublist(8);
    if (flag == 1) {
      throw const FormatException('LZO compression is not supported');
    } else if (flag == 2) {
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
    // keyNumEntries: total number of key entries across all key blocks.
    // The current reader derives per-entry data from each decompressed block,
    // but the MDX stream still includes this field and must be advanced.
    await fileInputStream.readUint64();
    // keyIndexDecompLen: decompressed byte length of the key index block.
    // Decompression currently reads until the block ends, so this value is
    // consumed for stream alignment rather than used directly.
    await fileInputStream.readUint64();
    final keyIndexCompLen = await fileInputStream.readUint64();
    // keyBlocksLen: total byte length of the following compressed key blocks.
    // Individual block sizes from the key index drive the reads below.
    await fileInputStream.readUint64();
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
      // firstWord: first key stored in this key block. The reader does not
      // need the value for lookup because it builds the full key list below,
      // but the bytes belong to the key index and must be consumed.
      await indexDs.readString(size: firstLength, utf8: utf8);
      var lastLength = (await indexDs.readUint16()) + 1;
      if (!utf8) {
        lastLength = lastLength * 2;
      }
      // lastWord: last key stored in this key block. It is index metadata used
      // by some readers for block selection; this implementation reads every
      // key block, so the field is consumed only to keep the stream aligned.
      await indexDs.readString(size: lastLength, utf8: utf8);
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
    // recordNumEntries: total record entries represented by all record blocks.
    // The key table already supplies offsets for query lookup in this reader.
    await fileInputStream.readUint64();
    // recordIndexLen: byte length of the record block index section.
    // The fixed-size index entries below are read directly from the stream.
    await fileInputStream.readUint64();
    // recordBlocksLen: total compressed byte length of all record blocks.
    // Each block's compressed and uncompressed lengths are stored per
    // index row.
    await fileInputStream.readUint64();
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
