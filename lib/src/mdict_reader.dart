import 'dart:io';
import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:xml/xml.dart';
import 'input_stream.dart';

class Key {
  String key;
  int offset;
  int length;
  Key(this.key, this.offset, [this.length = -1]);
}

class Record {
  int comp_size;
  int decomp_size;
  Record(this.comp_size, this.decomp_size);
}

class MdictReader {
  String path;
  late Map<String, String> _header;
  late List<Key> _key_list;
  late List<Record> _record_list;
  late int _record_block_offset;

  MdictReader(this.path) {
    var _in = FileInputStream(path, bufferSize: 64 * 1024);
    _header = _read_header(_in);
    _key_list = _read_keys(_in);
    _record_list = _read_records(_in);
    _record_block_offset = _in.position;
    _in.close();
  }

  List<String> keys() {
    return _key_list.map((key) => key.key).toList();
  }

  Future<dynamic> query(String word) async {
    var mdd = path.endsWith('.mdd');
    var keys = _key_list.where((key) => key.key == word).toList();
    final records = [];
    for (var key in keys) {
      final record = await _read_record(key.key, key.offset, key.length, mdd);
      records.add(record);
    }
    if (mdd) {
      return records[0];
    }
    return records.join('\n---\n');
  }

  Map<String, String> _read_header(FileInputStream _in) {
    var header_length = _in.readUint32();
    var header = _in.readString(size: header_length, utf8: false);
    _in.skip(4);
    return _parse_header(header);
  }

  Map<String, String> _parse_header(String header) {
    var attributes = <String, String>{};
    var doc = XmlDocument.parse(header);
    doc.rootElement.attributes.forEach((a) {
      attributes[a.name.local] = a.value;
    });
    return attributes;
  }

  List<Key> _read_keys(FileInputStream _in) {
    var encrypted = _header['Encrypted'] == '2';
    var utf8 = _header['Encoding'] == 'UTF-8';
    var key_num_blocks = _in.readUint64();
    // ignore: unused_local_variable
    var key_num_entries = _in.readUint64();
    // ignore: unused_local_variable
    var key_index_decomp_len = _in.readUint64();
    var key_index_comp_len = _in.readUint64();
    // ignore: unused_local_variable
    var key_blocks_len = _in.readUint64();
    _in.skip(4);
    var comp_size = List.filled(key_num_blocks, -1);
    var decomp_size = List.filled(key_num_blocks, -1);
    var num_entries = List.filled(key_num_blocks, -1);
    var index_comp_block = _in.readBytes(key_index_comp_len);
    if (encrypted) {
      var key = _compute_key(index_comp_block);
      _decrypt_block(key, index_comp_block, 8);
    }
    var index_ds = _decompress_block(index_comp_block);
    for (var i = 0; i < key_num_blocks; i++) {
      num_entries[i] = index_ds.readUint64();
      var first_length = index_ds.readUint16() + 1;
      if (!utf8) {
        first_length = first_length * 2;
      }
      // ignore: unused_local_variable
      var first_word = index_ds.readString(size: first_length, utf8: utf8);
      var last_length = index_ds.readUint16() + 1;
      if (!utf8) {
        last_length = last_length * 2;
      }
      // ignore: unused_local_variable
      var last_word = index_ds.readString(size: last_length, utf8: utf8);
      comp_size[i] = index_ds.readUint64();
      decomp_size[i] = index_ds.readUint64();
    }
    var key_list = <Key>[];
    for (var i = 0; i < key_num_blocks; i++) {
      var key_comp_block = _in.readBytes(comp_size[i]);
      var block_in = _decompress_block(key_comp_block);
      for (var j = 0; j < num_entries[i]; j++) {
        var offset = block_in.readUint64();
        var word = block_in.readString(utf8: utf8);
        if (key_list.isNotEmpty) {
          key_list[key_list.length - 1].length =
              offset - key_list[key_list.length - 1].offset;
        }
        key_list.add(Key(word, offset));
      }
    }
    return key_list;
  }

  List<Record> _read_records(FileInputStream _in) {
    var record_num_blocks = _in.readUint64();
    // ignore: unused_local_variable
    var record_num_entries = _in.readUint64();
    // ignore: unused_local_variable
    var record_index_len = _in.readUint64();
    // ignore: unused_local_variable
    var record_blocks_len = _in.readUint64();
    var record_list = <Record>[];
    for (var i = 0; i < record_num_blocks; i++) {
      var record_block_comp_size = _in.readUint64();
      var record_block_decomp_size = _in.readUint64();
      record_list.add(Record(record_block_comp_size, record_block_decomp_size));
    }
    return record_list;
  }

  Future<dynamic> _read_record(
      String word, int offset, int length, bool mdd) async {
    var compressed_offset = 0;
    var decompressed_offset = 0;
    var compressed_size = 0;
    var decompressed_size = 0;
    for (var record in _record_list) {
      compressed_size = record.comp_size;
      decompressed_size = record.decomp_size;
      if ((decompressed_offset + decompressed_size) > offset) {
        break;
      }
      decompressed_offset += decompressed_size;
      compressed_offset += compressed_size;
    }
    var _in = await File(path).open();
    await _in.setPosition(_record_block_offset + compressed_offset);
    var block = await _in.read(compressed_size);
    await _in.close();
    var block_in = _decompress_block(block);
    block_in.skip(offset - decompressed_offset);
    if (mdd) {
      var record_block = block_in.toUint8List();
      if (length > 0) {
        return record_block.sublist(0, length);
      } else {
        return record_block;
      }
    } else {
      var utf8 = _header['Encoding'] == 'UTF-8';
      return block_in.readString(size: length, utf8: utf8);
    }
  }

  InputStream _decompress_block(Uint8List comp_block) {
    var flag = comp_block[0];
    var data = comp_block.sublist(8);
    if (flag == 2) {
      return BytesInputStream(zlib.decoder.convert(data) as Uint8List);
    } else {
      return BytesInputStream(data);
    }
  }

  void _decrypt_block(Uint8List key, Uint8List data, int offset) {
    var previous = 0x36;
    for (var i = 0; i < data.length - offset; i++) {
      var t = (data[i + offset] >> 4 | data[i + offset] << 4) & 0xff;
      t = t ^ previous ^ (i & 0xff) ^ key[i % key.length];
      previous = data[i + offset];
      data[i + offset] = t;
    }
  }

  Uint8List _compute_key(Uint8List data) {
    var ripemd128 = Digest('RIPEMD-128');
    ripemd128.update(data, 4, 4);
    ripemd128.update(
        Uint8List.fromList(const <int>[0x95, 0x36, 0x00, 0x00]), 0, 4);
    var key = Uint8List(16);
    ripemd128.doFinal(key, 0);
    return key;
  }
}