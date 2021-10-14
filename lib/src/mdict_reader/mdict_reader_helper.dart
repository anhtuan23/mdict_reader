part of 'mdict_reader.dart';

abstract class MdictReaderHelper {

  static InputStream _decompressBlock(Uint8List compBlock) {
    var flag = compBlock[0];
    var data = compBlock.sublist(8);
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
    var ripemd128 = Digest('RIPEMD-128');
    ripemd128.update(data, 4, 4);
    ripemd128.update(
        Uint8List.fromList(const <int>[0x95, 0x36, 0x00, 0x00]), 0, 4);
    var key = Uint8List(16);
    ripemd128.doFinal(key, 0);
    return key;
  }

  static Future<List<MdictKey>> _readKeys(
    FileInputStream _in,
    Map<String, String> _header,
  ) async {
    var encrypted = _header['encrypted'] == '2';
    var utf8 = _header['encoding'] == 'UTF-8';
    var keyNumBlocks = await _in.readUint64();
    // ignore: unused_local_variable
    var keyNumEntries = await _in.readUint64();
    // ignore: unused_local_variable
    var keyIndexDecompLen = await _in.readUint64();
    var keyIndexCompLen = await _in.readUint64();
    // ignore: unused_local_variable
    var keyBlocksLen = await _in.readUint64();
    await _in.skip(4);
    var compSize = List.filled(keyNumBlocks, -1);
    var decompSize = List.filled(keyNumBlocks, -1);
    var numEntries = List.filled(keyNumBlocks, -1);
    var indexCompBlock = await _in.readBytes(keyIndexCompLen);
    if (encrypted) {
      var key = _computeKey(indexCompBlock);
      _decryptBlock(key, indexCompBlock, 8);
    }
    var indexDs = _decompressBlock(indexCompBlock);
    for (var i = 0; i < keyNumBlocks; i++) {
      numEntries[i] = await indexDs.readUint64();
      var firstLength = (await indexDs.readUint16()) + 1;
      if (!utf8) {
        firstLength = firstLength * 2;
      }
      // ignore: unused_local_variable
      var firstWord = await indexDs.readString(size: firstLength, utf8: utf8);
      var lastLength = (await indexDs.readUint16()) + 1;
      if (!utf8) {
        lastLength = lastLength * 2;
      }
      // print('Last length: $last_length\n utf8: $utf8\n\n');
      // ignore: unused_local_variable
      var lastWord = await indexDs.readString(size: lastLength, utf8: utf8);
      compSize[i] = await indexDs.readUint64();
      decompSize[i] = await indexDs.readUint64();
    }
    var keyList = <MdictKey>[];
    for (var i = 0; i < keyNumBlocks; i++) {
      var keyCompBlock = await _in.readBytes(compSize[i]);
      var blockIn = _decompressBlock(keyCompBlock);
      for (var j = 0; j < numEntries[i]; j++) {
        var offset = await blockIn.readUint64();
        var word = await blockIn.readString(utf8: utf8);
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
  static Future<List<Uint32List>> _readRecords(FileInputStream _in) async {
    final recordNumBlocks = await _in.readUint64();
    // ignore: unused_local_variable
    final recordNumEntries = await _in.readUint64();
    // ignore: unused_local_variable
    final recordIndexLen = await _in.readUint64();
    // ignore: unused_local_variable
    final recordBlocksLen = await _in.readUint64();
    final compressedSize = Uint32List(recordNumBlocks);
    final uncompressedSize = Uint32List(recordNumBlocks);
    for (var i = 0; i < recordNumBlocks; i++) {
      compressedSize[i] = await _in.readUint64();
      uncompressedSize[i] = await _in.readUint64();
    }
    return [compressedSize, uncompressedSize];
  }

  static Map<String, String> _parseHeader(String header) {
    var attributes = <String, String>{};
    var doc = parseFragment(header);
    for (var entry in doc.nodes.first.attributes.entries) {
      attributes[entry.key.toString()] = entry.value;
    }
    return attributes;
  }

  static Future<Map<String, String>> _readHeader(FileInputStream _in) async {
    var headerLength = await _in.readUint32();
    var header = await _in.readString(size: headerLength, utf8: false);
    await _in.skip(4);
    return _parseHeader(header);
  }
}
