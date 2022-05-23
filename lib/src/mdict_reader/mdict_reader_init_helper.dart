part of 'mdict_reader.dart';

abstract class MdictReaderInitHelper {
  static bool _mdictNotExistInDb({
    required String filePath,
    required Database db,
  }) {
    final metaCheckResult = db.select(
      '''
        SELECT EXISTS (
          SELECT 1 
          FROM ${MdictMeta.tableName}
          WHERE ${MdictMeta.filePathColumnName} = '$filePath'
        )
        ''',
    );
    if (metaCheckResult.single.values.first == 0) return true;
    final keyCheckResult = db.select(
      '''
        SELECT EXISTS (
          SELECT 1 
          FROM ${MdictKey.tableName}
          WHERE ${MdictKey.filePathColumnName} = '$filePath'
        )
        ''',
    );
    if (keyCheckResult.single.values.first == 0) return true;
    final recordCheckResult = db.select(
      '''
        SELECT EXISTS (
          SELECT 1 
          FROM ${MdictRecord.tableName}
          WHERE ${MdictRecord.filePathColumnName} = '$filePath'
        )
        ''',
    );
    if (recordCheckResult.single.values.first == 0) return true;
    return false;
  }

  static Future<IndexInfo> _getIndexInfo(String path) async {
    final inputStream =
        await FileInputStream.create(path, bufferSize: 64 * 1024);
    final header = await MdictReaderHelper._readHeader(inputStream);

    final version = header['generatedbyengineversion'] ?? '2';
    if (double.parse(version).truncate() != 2) {
      throw Exception('This program does not support mdict version $version');
    }
    final keyList = await MdictReaderHelper._readKeys(inputStream, header);
    final recordSizes = await MdictReaderHelper._readRecords(inputStream);
    header[MdictReader.recordBlockOffsetKey] = inputStream.position.toString();
    await inputStream.close();
    return IndexInfo(header, keyList, recordSizes[0], recordSizes[1]);
  }

  static void _insertKeys({
    required Database db,
    required List<MdictKey> keys,
    required String dictFilePath,
    required Map<int, PreparedStatement> statementMap,
  }) {
    if (!statementMap.containsKey(keys.length)) {
      final statementBuilder = StringBuffer(
        '''
          INSERT INTO '${MdictKey.tableName}' 
            (${MdictKey.wordColumnName}, 
             ${MdictKey.offsetColumnName}, 
             ${MdictKey.lengthColumnName},
             ${MdictKey.filePathColumnName}
            ) 
          VALUES 
        ''',
      )..writeAll(
          Iterable<dynamic>.generate(keys.length, (_) => '(?, ?, ?, ?)'),
          ', ',
        );
      final statement = db.prepare(statementBuilder.toString());
      statementMap[keys.length] = statement;
    }

    final parameters = keys
        .expand(
          (key) => [
            key.word,
            key.offset.toString(),
            key.length.toString(),
            dictFilePath,
          ],
        )
        .toList();
    statementMap[keys.length]!.execute(parameters);
  }

  static Future<void> _buildIndex({
    required String dictFilePath,
    required Database db,
    StreamController<MdictProgress>? progressController,
  }) async {
    final fileName = p.basename(dictFilePath);

    progressController?.add(MdictProgress('$fileName: Getting index info ...'));
    final indexInfo = await _getIndexInfo(dictFilePath);

    /// META table
    progressController
        ?.add(MdictProgress('$fileName: Building meta table ...'));
    db.execute(
      '''
      DELETE FROM '${MdictMeta.tableName}' 
      WHERE  ${MdictMeta.filePathColumnName} = '$dictFilePath';
    ''',
    );
    final metaStmt = db.prepare(
      '''
          INSERT INTO '${MdictMeta.tableName}' 
            (${MdictMeta.keyColumnName}, 
            ${MdictMeta.valueColumnName}, 
            ${MdictMeta.filePathColumnName}
            ) 
          VALUES (?, ?, ?)
        ''',
    );
    for (final info in indexInfo.metaInfo.entries) {
      metaStmt.execute([info.key, info.value, dictFilePath]);
    }
    metaStmt.dispose();

    /// KEYS table
    final totalKeys = indexInfo.keyList.length;
    progressController
        ?.add(MdictProgress('$fileName: Building key table 0/$totalKeys ...'));

    db.execute(
      '''
      DELETE FROM '${MdictKey.tableName}' 
      WHERE  ${MdictKey.filePathColumnName} = '$dictFilePath';
    ''',
    );

    // SQLite SQLITE_MAX_VARIABLE_NUMBER = 32766
    // => We can insert 32766 / 4 ~ 8191 keys at a time
    const countsEachTime = 8191;

    final partitionedKeyIter = partition(indexInfo.keyList, countsEachTime);

    final statementMap = <int, PreparedStatement>{};

    var insertedCount = 0;
    for (final keyList in partitionedKeyIter) {
      _insertKeys(
        db: db,
        keys: keyList,
        dictFilePath: dictFilePath,
        statementMap: statementMap,
      );
      insertedCount += keyList.length;
      progressController?.add(
        MdictProgress(
          '$fileName: Building key table $insertedCount/$totalKeys ...',
        ),
      );
    }

    for (final statement in statementMap.values) {
      statement.dispose();
    }

    /// RECORDS table
    progressController
        ?.add(MdictProgress('$fileName: Building records table ...'));

    db.execute(
      '''
      DELETE FROM '${MdictRecord.tableName}' 
      WHERE  ${MdictRecord.filePathColumnName} = '$dictFilePath';
    ''',
    );
    db.prepare(
      '''
          INSERT INTO ${MdictRecord.tableName} 
            (${MdictRecord.compressedSizeColumnName}, 
            ${MdictRecord.uncompressedSizeColumnName},
            ${MdictRecord.filePathColumnName}
            ) 
          VALUES (?, ?, ?)
        ''',
    )
      ..execute([
        indexInfo.recordsCompressedSizes.buffer.asUint8List(),
        indexInfo.recordsUncompressedSizes.buffer.asUint8List(),
        dictFilePath,
      ])
      ..dispose();

    progressController
        ?.add(MdictProgress('$fileName: Finished building index'));
  }

  static Future<Map<String, String>> _getHeader(
    String filePath,
    Database db,
  ) async {
    final header = <String, String>{};
    final resultSet = db.select(
      '''
        SELECT ${MdictMeta.keyColumnName}, ${MdictMeta.valueColumnName} 
        FROM ${MdictMeta.tableName}
        WHERE ${MdictMeta.filePathColumnName} = '$filePath'
        ''',
    );
    for (final row in resultSet) {
      header[row[MdictMeta.keyColumnName] as String] =
          row[MdictMeta.valueColumnName] as String;
    }
    return header;
  }

  static Future<List<Uint32List>> _getRecordList(
    String filePath,
    Database db,
  ) async {
    final resultSet = db.select(
      '''
          SELECT ${MdictRecord.compressedSizeColumnName}, ${MdictRecord.uncompressedSizeColumnName} 
          FROM ${MdictRecord.tableName} 
          WHERE ${MdictRecord.filePathColumnName} = '$filePath'
        ''',
    );
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
    required Database db,
    StreamController<MdictProgress>? progressController,
  }) async {
    final fileName = MdictHelpers.getDictNameFromPath(filePath);
    if (_mdictNotExistInDb(filePath: filePath, db: db)) {
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
