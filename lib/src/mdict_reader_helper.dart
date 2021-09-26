part of 'mdict_reader.dart';

abstract class MdictReaderHelper {
  static String _getMetaTableName(String filePath) => '${filePath}_meta';
  static String _getKeysTableName(String filePath) => '${filePath}_keys';
  static String _getRecordsTableName(String filePath) => '${filePath}_records';

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

  static Future<IndexInfo> _getIndexInfo(String path) async {
    var inputStream = await FileInputStream.create(path, bufferSize: 64 * 1024);
    final header = await _readHeader(inputStream);

    final version = header['generatedbyengineversion'] ?? '2';
    if (double.parse(version).truncate() != 2) {
      throw Exception('This program does not support mdict version $version');
    }
    final keyList = await _readKeys(inputStream, header);
    final recordSizes = await _readRecords(inputStream);
    header[MdictReader.recordBlockOffsetKey] = inputStream.position.toString();
    await inputStream.close();
    return IndexInfo(header, keyList, recordSizes[0], recordSizes[1]);
  }

  static Future<void> _buildIndex({
    required String dictFilePath,
    required Database db,
    StreamController<MdictProgress>? progressController,
  }) async {
    final fileName = p.basename(dictFilePath);
    final metaTableName = _getMetaTableName(dictFilePath);
    final keysTableName = _getKeysTableName(dictFilePath);
    final recordsTableName = _getRecordsTableName(dictFilePath);

    for (final tableName in [metaTableName, keysTableName, recordsTableName]) {
      progressController
          ?.add(MdictProgress('$fileName: Droping $tableName table ...'));
      db.execute("DROP TABLE IF EXISTS '$tableName'");
    }

    progressController?.add(MdictProgress('$fileName: Getting index info ...'));
    final indexInfo = await _getIndexInfo(dictFilePath);

    /// META table
    progressController
        ?.add(MdictProgress('$fileName: Building meta table ...'));
    db.execute('''
    CREATE TABLE '$metaTableName' (
      ${MdictMeta.keyColumnName} TEXT NOT NULL,
      ${MdictMeta.valueColumnName} TEXT NOT NULL
    );
    ''');
    final metaStmt = db.prepare(
        "INSERT INTO '$metaTableName' (${MdictMeta.keyColumnName}, ${MdictMeta.valueColumnName}) VALUES (?, ?)");
    for (var info in indexInfo.metaInfo.entries) {
      metaStmt.execute([info.key, info.value]);
    }
    metaStmt.dispose();

    /// KEYS table
    final totalKeys = indexInfo.keyList.length;
    progressController
        ?.add(MdictProgress('$fileName: Building key table 0/$totalKeys ...'));
    db.execute('''
      CREATE VIRTUAL TABLE '$keysTableName' USING fts5(
        ${MdictKey.wordColumnName},
        ${MdictKey.offsetColumnName} UNINDEXED,
        ${MdictKey.lengthColumnName} UNINDEXED,
      );
      ''');

    // Insert 10000 keys at a time
    final countsEachTime = 10000;

    final partitionedKeyIter = partition(indexInfo.keyList, countsEachTime);

    final statementBuilder = StringBuffer('''
        INSERT INTO '$keysTableName' 
        (${MdictKey.wordColumnName}, 
          ${MdictKey.offsetColumnName}, 
          ${MdictKey.lengthColumnName}) 
        VALUES ''');
    statementBuilder.writeAll(
      Iterable.generate(countsEachTime, (_) => '(?, ?, ?)'),
      ', ',
    );
    final keysStmt = db.prepare(statementBuilder.toString());

    var insertedCount = 0;
    for (var keyIter
        in partitionedKeyIter.take(partitionedKeyIter.length - 1)) {
      final parameters = keyIter
          .expand(
              (key) => [key.word, key.offset.toString(), key.length.toString()])
          .toList();
      keysStmt.execute(parameters);
      insertedCount += countsEachTime;
      progressController?.add(MdictProgress(
          '$fileName: Building key table $insertedCount/$totalKeys ...'));
    }
    keysStmt.dispose();

    // Insert remaining keys
    final remainingKeys = partitionedKeyIter.last;
    final remainingStatementBuilder = StringBuffer('''
        INSERT INTO '$keysTableName' 
          (${MdictKey.wordColumnName}, 
          ${MdictKey.offsetColumnName}, 
          ${MdictKey.lengthColumnName}) 
        VALUES ''');
    remainingStatementBuilder.writeAll(
      Iterable.generate(remainingKeys.length, (_) => '(?, ?, ?)'),
      ', ',
    );
    final remainingKeysStmt = db.prepare(remainingStatementBuilder.toString());

    final remainingParameters = remainingKeys
        .expand(
            (key) => [key.word, key.offset.toString(), key.length.toString()])
        .toList();
    remainingKeysStmt.execute(remainingParameters);

    progressController?.add(MdictProgress(
        '$fileName: Building key table $totalKeys/$totalKeys ...'));

    remainingKeysStmt.dispose();

    /// RECORDS table
    progressController
        ?.add(MdictProgress('$fileName: Building records table ...'));
    db.execute('''
    CREATE TABLE '$recordsTableName' (
      ${MdictRecord.compressedSizeColumnName} BLOB NOT NULL,
      ${MdictRecord.uncompressedSizeColumnName} BLOB NOT NULL
    );
    ''');
    final recordsStmt = db.prepare('''
        INSERT INTO '$recordsTableName' 
          (${MdictRecord.compressedSizeColumnName}, 
          ${MdictRecord.uncompressedSizeColumnName}) 
        VALUES (?, ?)''');

    recordsStmt.execute([
      indexInfo.recordsCompressedSizes.buffer.asUint8List(),
      indexInfo.recordsUncompressedSizes.buffer.asUint8List(),
    ]);
    recordsStmt.dispose();

    progressController
        ?.add(MdictProgress('$fileName: Finished building index'));
  }

  static Future<Map<String, String>> _getHeader(
    String filePath,
    Database db,
  ) async {
    final header = <String, String>{};
    final resultSet =
        db.select("SELECT * FROM '${_getMetaTableName(filePath)}'");
    for (final row in resultSet) {
      header[row[MdictMeta.keyColumnName]] = row[MdictMeta.valueColumnName];
    }
    return header;
  }

  static Future<List<Uint32List>> _getRecordList(
    String filePath,
    Database db,
  ) async {
    final resultSet = db.select('''
        SELECT ${MdictRecord.compressedSizeColumnName}, ${MdictRecord.uncompressedSizeColumnName} 
        FROM '${_getRecordsTableName(filePath)}' ''');
    final row = resultSet.first;
    final compressedSizes =
        (row[MdictRecord.compressedSizeColumnName] as Uint8List)
            .buffer
            .asUint32List();
    final uncompressedSizes =
        (row[MdictRecord.uncompressedSizeColumnName] as Uint8List)
            .buffer
            .asUint32List();
    return [compressedSizes, uncompressedSizes];
  }

  static Future<MdictReader> init({
    required String filePath,
    required Iterable<String> currentTableNames,
    required Database db,
    StreamController<MdictProgress>? progressController,
  }) async {
    final fileName = MdictHelpers.getDictNameFromPath(filePath);
    if (!(currentTableNames.contains(_getMetaTableName(filePath)) &&
        currentTableNames.contains(_getKeysTableName(filePath)) &&
        currentTableNames.contains(_getRecordsTableName(filePath)))) {
      progressController
          ?.add(MdictProgress('Building index for $fileName ...'));

      await _buildIndex(
        dictFilePath: filePath,
        db: db,
        progressController: progressController,
      );
    }
    progressController?.add(MdictProgress('Getting headers of $fileName ...'));
    final header = await _getHeader(filePath, db);

    progressController
        ?.add(MdictProgress('Getting record list of $fileName ...'));
    final recordSizes = await _getRecordList(filePath, db);

    progressController
        ?.add(MdictProgress('Finished creating $fileName dictionary'));
    return MdictReader(
      path: filePath,
      db: db,
      header: header,
      recordsCompressedSizes: recordSizes[0],
      recordsUncompressedSizes: recordSizes[1],
    );
  }
}
