import 'dart:io';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:pointycastle/api.dart';
import 'package:xml/xml.dart';
import 'input_stream.dart';

class MdictKey {
  MdictKey(this.key, this.offset, [this.length = -1]);

  String key;
  int offset;
  int length;
}

class Record {
  Record(this.compSize, this.decompSize);

  int compSize;
  int decompSize;
}

/// Need a stable hash to work with IsolatedManager's reload
class MdictFiles extends Equatable {
  const MdictFiles(this.mdictFilePath, [this.cssPath = '']);

  /// Can be a mdx or mdd file
  final String mdictFilePath;
  final String cssPath;

  @override
  List<Object?> get props => [mdictFilePath, cssPath];
}

class MdictSearchResultLists {
  const MdictSearchResultLists(this.startsWithList, this.containsList);

  final List<String> startsWithList;
  final List<String> containsList;

  @override
  String toString() {
    return 'startsWithList: $startsWithList\ncontainsList: $containsList';
  }
}

class MdictReader {
  MdictReader._(this.path, this._cssPath);

  final String path;
  final String _cssPath;
  late String _cssContent;
  late Map<String, String> _header;
  late List<MdictKey> _keyList;
  late List<Record> _recordList;
  late int _recordBlockOffset;
  late String? _name;

  bool get isMdd => path.endsWith('.mdd');

  String get name => _name ?? 'Untitled';

  static Future<MdictReader> create(MdictFiles mdictFiles) async {
    final mdict = MdictReader._(mdictFiles.mdictFilePath, mdictFiles.cssPath);
    await mdict.init();
    return mdict;
  }

  Future<void> init() async {
    var _in = await FileInputStream.create(path, bufferSize: 64 * 1024);
    _cssContent = await _readCss();
    _header = await _readHeader(_in);
    if (double.parse(_header['GeneratedByEngineVersion'] ?? '2') < 2) {
      throw Exception('This program does not support mdict version 1.x');
    }
    _name = _header['Title'];
    _keyList = await _readKeys(_in);
    _recordList = await _readRecords(_in);
    _recordBlockOffset = _in.position;
    await _in.close();
  }

  List<String> keys() {
    return _keyList.map((key) => key.key).toList();
  }

  Future<MdictSearchResultLists> search(String term) {
    return Future(() {
      final startsWithList = <String>[];
      final containsList = <String>[];

      term = term.trim().toLowerCase();

      for (var key in _keyList) {
        if (key.key.toLowerCase().startsWith(term)) {
          startsWithList.add(key.key);
        } else if (key.key.toLowerCase().contains(term)) {
          containsList.add(key.key);
        }
      }

      return MdictSearchResultLists(startsWithList, containsList);
    });
  }

  /// * Should only be used in a mdx reader
  /// Return [html, css] of result
  Future<List<String>> query(String keyWord) async {
    final definitionHtmlString =
        (await _queryHtmls(keyWord)).join('<br/>- - - - -<br/>');
    return [definitionHtmlString, _cssContent];
  }

  /// Find Html definitions of a [keyWord]
  /// Can be called recursively to resolve `@@@LINK=`
  Future<List<String>> _queryHtmls(String keyWord) async {
    var records = <String>[];

    for (var key in _keyList.where((key) => key.key == keyWord)) {
      String record = await _readRecord(key.key, key.offset, key.length, isMdd);
      if (record.startsWith('@@@LINK=')) {
        final _keyWord = record.substring(8).trim();
        records.addAll(await _queryHtmls(_keyWord));
      } else {
        records.add(record.trim());
      }
    }
    return records;
  }

  Future<dynamic> legacyQuery(String keyWord) async {
    var keys = _keyList.where((key) => key.key == keyWord).toList();
    final records = [];
    for (var key in keys) {
      final record = await _readRecord(key.key, key.offset, key.length, isMdd);
      records.add(record);
    }
    if (isMdd) {
      return records[0];
    }
    return records.join('\n---\n');
  }

  Future<String> _readCss() async {
    // * Check file.exists() of empty path cause CRASH: Stack dump aborted because InitialRegisterCheck failed
    if (_cssPath.isEmpty) return '';
    final file = File(_cssPath);
    if (await file.exists()) {
      return file.readAsString();
    }
    return '';
  }

  Future<Map<String, String>> _readHeader(FileInputStream _in) async {
    var headerLength = await _in.readUint32();
    var header = await _in.readString(size: headerLength, utf8: false);
    await _in.skip(4);
    return _parseHeader(header);
  }

  Map<String, String> _parseHeader(String header) {
    var attributes = <String, String>{};
    var doc = XmlDocument.parse(header);
    for (var a in doc.rootElement.attributes) {
      attributes[a.name.local] = a.value;
    }
    return attributes;
  }

  Future<List<MdictKey>> _readKeys(FileInputStream _in) async {
    var encrypted = _header['Encrypted'] == '2';
    var utf8 = _header['Encoding'] == 'UTF-8';
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

  Future<List<Record>> _readRecords(FileInputStream _in) async {
    var recordNumBlocks = await _in.readUint64();
    // ignore: unused_local_variable
    var recordNumEntries = await _in.readUint64();
    // ignore: unused_local_variable
    var recordIndexLen = await _in.readUint64();
    // ignore: unused_local_variable
    var recordBlocksLen = await _in.readUint64();
    var recordList = <Record>[];
    for (var i = 0; i < recordNumBlocks; i++) {
      var recordBlockCompSize = await _in.readUint64();
      var recordBlockDecompSize = await _in.readUint64();
      recordList.add(Record(recordBlockCompSize, recordBlockDecompSize));
    }
    return recordList;
  }

  Future<dynamic> _readRecord(
      String word, int offset, int length, bool isMdd) async {
    var compressedOffset = 0;
    var decompressedOffset = 0;
    var compressedSize = 0;
    var decompressedSize = 0;
    for (var record in _recordList) {
      compressedSize = record.compSize;
      decompressedSize = record.decompSize;
      if ((decompressedOffset + decompressedSize) > offset) {
        break;
      }
      decompressedOffset += decompressedSize;
      compressedOffset += compressedSize;
    }
    var _in = await File(path).open();
    await _in.setPosition(_recordBlockOffset + compressedOffset);
    var block = await _in.read(compressedSize);
    await _in.close();
    var blockIn = _decompressBlock(block);
    await blockIn.skip(offset - decompressedOffset);
    if (isMdd) {
      var recordBlock = await blockIn.toUint8List();
      if (length > 0) {
        return recordBlock.sublist(0, length);
      } else {
        return recordBlock;
      }
    } else {
      var utf8 = _header['Encoding'] == 'UTF-8';
      return blockIn.readString(size: length, utf8: utf8);
    }
  }

  InputStream _decompressBlock(Uint8List compBlock) {
    var flag = compBlock[0];
    var data = compBlock.sublist(8);
    if (flag == 2) {
      return BytesInputStream(zlib.decoder.convert(data) as Uint8List);
    } else {
      return BytesInputStream(data);
    }
  }

  void _decryptBlock(Uint8List key, Uint8List data, int offset) {
    var previous = 0x36;
    for (var i = 0; i < data.length - offset; i++) {
      var t = (data[i + offset] >> 4 | data[i + offset] << 4) & 0xff;
      t = t ^ previous ^ (i & 0xff) ^ key[i % key.length];
      previous = data[i + offset];
      data[i + offset] = t;
    }
  }

  Uint8List _computeKey(Uint8List data) {
    var ripemd128 = Digest('RIPEMD-128');
    ripemd128.update(data, 4, 4);
    ripemd128.update(
        Uint8List.fromList(const <int>[0x95, 0x36, 0x00, 0x00]), 0, 4);
    var key = Uint8List(16);
    ripemd128.doFinal(key, 0);
    return key;
  }
}
