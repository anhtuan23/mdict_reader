part of 'mdict_reader.dart';

abstract class MdictReaderHelper {
  static InputStream _decompressBlock(Uint8List compBlock) {
    final flag = compBlock[0];
    final data = compBlock.sublist(8);
    if (flag == 1) {
      return BytesInputStream(_decompressLzoBlock(data));
    } else if (flag == 2) {
      return BytesInputStream(zlib.decoder.convert(data) as Uint8List);
    } else {
      return BytesInputStream(data);
    }
  }

  static Uint8List _decompressLzoBlock(Uint8List input) {
    var inputOffset = 0;
    final output = <int>[];

    int readByte() {
      if (inputOffset >= input.length) {
        throw const FormatException('Invalid LZO block');
      }
      return input[inputOffset++];
    }

    int peekByte() {
      if (inputOffset >= input.length) {
        throw const FormatException('Invalid LZO block');
      }
      return input[inputOffset];
    }

    int readExtendedLength(int value, int base) {
      var length = value;
      while (peekByte() == 0) {
        length += 255;
        inputOffset++;
      }
      return length + base + readByte();
    }

    void copyLiteral(int count) {
      if (inputOffset + count > input.length) {
        throw const FormatException('Invalid LZO block');
      }
      output.addAll(input.sublist(inputOffset, inputOffset + count));
      inputOffset += count;
    }

    void copyMatch(int matchOffset, int count) {
      if (matchOffset < 0 || matchOffset >= output.length) {
        throw const FormatException('Invalid LZO block');
      }
      var currentMatchOffset = matchOffset;
      for (var i = 0; i < count; i++) {
        output.add(output[currentMatchOffset++]);
      }
    }

    int? nextMatchToken() {
      final literalCount = input[inputOffset - 2] & 3;
      if (literalCount == 0) return null;
      copyLiteral(literalCount);
      return readByte();
    }

    void copyFirstLiteralMatch(int token) {
      final matchOffset =
          output.length - 0x0801 - (token >> 2) - (readByte() << 2);
      copyMatch(matchOffset, 3);
    }

    bool copyMatchForToken(int token) {
      var length = 0;
      var matchOffset = 0;
      if (token >= 64) {
        matchOffset =
            output.length - 1 - ((token >> 2) & 7) - (readByte() << 3);
        length = (token >> 5) + 1;
      } else if (token >= 32) {
        length = token & 31;
        if (length == 0) {
          length = readExtendedLength(length, 31);
        }
        final firstOffsetByte = readByte();
        final secondOffsetByte = readByte();
        matchOffset = output.length -
            1 -
            (firstOffsetByte >> 2) -
            (secondOffsetByte << 6);
        length += 2;
      } else if (token >= 16) {
        length = token & 7;
        final highOffset = (token & 8) << 11;
        if (length == 0) {
          length = readExtendedLength(length, 7);
        }
        final firstOffsetByte = readByte();
        final secondOffsetByte = readByte();
        matchOffset = output.length -
            highOffset -
            (firstOffsetByte >> 2) -
            (secondOffsetByte << 6);
        if (matchOffset == output.length) return false;
        matchOffset -= 0x4000;
        length += 2;
      } else {
        matchOffset = output.length - 1 - (token >> 2) - (readByte() << 2);
        length = 2;
      }
      copyMatch(matchOffset, length);
      return true;
    }

    bool copyMatches(int token) {
      var localToken = token;
      while (true) {
        if (!copyMatchForToken(localToken)) return false;
        final nextToken = nextMatchToken();
        if (nextToken == null) return true;
        localToken = nextToken;
      }
    }

    var isDone = false;
    if (peekByte() > 17) {
      final literalCount = readByte() - 17;
      copyLiteral(literalCount);
      final token = readByte();
      if (literalCount < 4 || token >= 16) {
        isDone = !copyMatches(token);
      } else {
        copyFirstLiteralMatch(token);
        final nextToken = nextMatchToken();
        if (nextToken != null) isDone = !copyMatches(nextToken);
      }
    }

    while (!isDone) {
      var token = readByte();
      if (token >= 16) {
        isDone = !copyMatches(token);
        continue;
      }
      if (token == 0) {
        token = readExtendedLength(token, 15);
      }
      copyLiteral(token + 3);
      token = readByte();
      if (token >= 16) {
        isDone = !copyMatches(token);
        continue;
      }
      copyFirstLiteralMatch(token);
      final nextToken = nextMatchToken();
      if (nextToken != null) isDone = !copyMatches(nextToken);
    }

    return Uint8List.fromList(output);
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
    final version = _version(header);
    final isVersion2 = version >= 2;
    final keyNumBlocks = await _readNumber(fileInputStream, version);
    // keyNumEntries: total number of key entries across all key blocks.
    // The current reader derives per-entry data from each decompressed block,
    // but the MDX stream still includes this field and must be advanced.
    await _readNumber(fileInputStream, version);
    // keyIndexDecompLen: decompressed byte length of the key index block.
    // Decompression currently reads until the block ends, so this value is
    // consumed for stream alignment rather than used directly.
    if (isVersion2) {
      await _readNumber(fileInputStream, version);
    }
    final keyIndexCompLen = await _readNumber(fileInputStream, version);
    // keyBlocksLen: total byte length of the following compressed key blocks.
    // Individual block sizes from the key index drive the reads below.
    await _readNumber(fileInputStream, version);
    if (isVersion2) {
      await fileInputStream.skip(4);
    }
    final compSize = List.filled(keyNumBlocks, -1);
    final decompSize = List.filled(keyNumBlocks, -1);
    final numEntries = List.filled(keyNumBlocks, -1);
    final indexCompBlock = await fileInputStream.readBytes(keyIndexCompLen);
    if (encrypted) {
      final key = _computeKey(indexCompBlock);
      _decryptBlock(key, indexCompBlock, 8);
    }
    final indexDs = isVersion2
        ? _decompressBlock(indexCompBlock)
        : BytesInputStream(indexCompBlock);
    for (var i = 0; i < keyNumBlocks; i++) {
      numEntries[i] = await _readNumber(indexDs, version);
      final firstLength = await _readKeyIndexTextSize(indexDs, version, utf8);
      // firstWord: first key stored in this key block. The reader does not
      // need the value for lookup because it builds the full key list below,
      // but the bytes belong to the key index and must be consumed.
      await indexDs.readString(size: firstLength, utf8: utf8);
      final lastLength = await _readKeyIndexTextSize(indexDs, version, utf8);
      // lastWord: last key stored in this key block. It is index metadata used
      // by some readers for block selection; this implementation reads every
      // key block, so the field is consumed only to keep the stream aligned.
      await indexDs.readString(size: lastLength, utf8: utf8);
      compSize[i] = await _readNumber(indexDs, version);
      decompSize[i] = await _readNumber(indexDs, version);
    }
    final keyList = <MdictKey>[];
    for (var i = 0; i < keyNumBlocks; i++) {
      final keyCompBlock = await fileInputStream.readBytes(compSize[i]);
      final blockIn = _decompressBlock(keyCompBlock);
      for (var j = 0; j < numEntries[i]; j++) {
        final offset = await _readNumber(blockIn, version);
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
    Map<String, String> header,
    FileInputStream fileInputStream,
  ) async {
    final version = _version(header);
    final recordNumBlocks = await _readNumber(fileInputStream, version);
    // recordNumEntries: total record entries represented by all record blocks.
    // The key table already supplies offsets for query lookup in this reader.
    await _readNumber(fileInputStream, version);
    // recordIndexLen: byte length of the record block index section.
    // The fixed-size index entries below are read directly from the stream.
    await _readNumber(fileInputStream, version);
    // recordBlocksLen: total compressed byte length of all record blocks.
    // Each block's compressed and uncompressed lengths are stored per
    // index row.
    await _readNumber(fileInputStream, version);
    final compressedSize = Uint32List(recordNumBlocks);
    final uncompressedSize = Uint32List(recordNumBlocks);
    for (var i = 0; i < recordNumBlocks; i++) {
      compressedSize[i] = await _readNumber(fileInputStream, version);
      uncompressedSize[i] = await _readNumber(fileInputStream, version);
    }
    return [compressedSize, uncompressedSize];
  }

  static double _version(Map<String, String> header) =>
      double.parse(header['generatedbyengineversion'] ?? '2');

  static Future<int> _readNumber(InputStream inputStream, double version) {
    if (version >= 2) return inputStream.readUint64();
    return inputStream.readUint32();
  }

  static Future<int> _readKeyIndexTextSize(
    InputStream inputStream,
    double version,
    bool utf8,
  ) async {
    if (version >= 2) {
      final terminatorSize = utf8 ? 1 : 2;
      final characterSize = utf8 ? 1 : 2;
      return (await inputStream.readUint16()) * characterSize + terminatorSize;
    }
    return inputStream.readByte();
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
