part of 'mdict_reader.dart';

abstract class MdictReaderInitHelper {
  static bool _mdictNotExistInDb({
    required String fileNameExt,
    required CommonDatabase db,
  }) {
    final metaCheckResult = db.select(
      '''
        SELECT EXISTS (
          SELECT 1 
          FROM ${MdictMeta.tableName}
          WHERE ${MdictMeta.fileNameColumnName} = ? 
        )
      ''',
      [fileNameExt],
    );
    if (metaCheckResult.single.values.first == 0) return true;
    final keyCheckResult = db.select(
      '''
        SELECT EXISTS (
          SELECT 1 
          FROM ${MdictKey.tableName}
          WHERE ${MdictKey.fileNameColumnName} = ?
        )
      ''',
      [fileNameExt],
    );
    if (keyCheckResult.single.values.first == 0) return true;
    final recordCheckResult = db.select(
      '''
        SELECT EXISTS (
          SELECT 1 
          FROM ${MdictRecord.tableName}
          WHERE ${MdictRecord.fileNameColumnName} = ?
        )
      ''',
      [fileNameExt],
    );
    if (recordCheckResult.single.values.first == 0) return true;
    return false;
  }

  /// Use externally for preliminary check if an mdx file can be indexed.
  static Future<bool> isSupportedVersion({required String path}) async {
    final inputStream = await FileInputStream.create(
      path,
      bufferSize: 64 * 1024,
    );
    final header = await MdictReaderHelper._readHeader(inputStream);
    final version = header['generatedbyengineversion'] ?? '2';
    await inputStream.close();
    return double.parse(version) >= 1;
  }

  static Future<IndexInfo> _getIndexInfo({
    required String path,
    required String fileName,
    required StreamController<MdictProgress>? progressController,
  }) async {
    progressController?.add(MdictProgressReaderHelperGetInfo(fileName));
    final inputStream = await FileInputStream.create(
      path,
      bufferSize: 64 * 1024,
    );
    progressController?.add(MdictProgressReaderHelperReadHeader(fileName));
    final header = await MdictReaderHelper._readHeader(inputStream);
    progressController?.add(MdictProgressReaderHelperReadKeys(fileName));
    final keyList = await MdictReaderHelper._readKeys(inputStream, header);
    progressController?.add(MdictProgressReaderHelperReadRecords(fileName));
    final recordSizes = await MdictReaderHelper._readRecords(
      header,
      inputStream,
    );
    header[MdictReader.recordBlockOffsetKey] = inputStream.position.toString();
    await inputStream.close();
    return IndexInfo(header, keyList, recordSizes[0], recordSizes[1]);
  }

  static void _insertKeys({
    required CommonDatabase db,
    required List<MdictKey> keys,
    required String dictFileNameExt,
    required Map<int, CommonPreparedStatement> statementMap,
  }) {
    if (!statementMap.containsKey(keys.length)) {
      final statementBuilder =
          StringBuffer(
            '''
          INSERT INTO '${MdictKey.tableName}' 
            (${MdictKey.wordColumnName}, 
             ${MdictKey.offsetColumnName}, 
             ${MdictKey.lengthColumnName},
             ${MdictKey.fileNameColumnName}
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
            dictFileNameExt,
          ],
        )
        .toList();
    statementMap[keys.length]!.execute(parameters);
  }

  static Future<void> _buildIndex({
    required String dictFilePath,
    required String fileNameExt,
    required CommonDatabase db,
    StreamController<MdictProgress>? progressController,
  }) async {
    final indexInfo = await _getIndexInfo(
      path: dictFilePath,
      fileName: fileNameExt,
      progressController: progressController,
    );

    /// META table
    progressController?.add(MdictProgressReaderHelperBuildMeta(fileNameExt));
    db.execute(
      '''
        DELETE FROM '${MdictMeta.tableName}' 
        WHERE  ${MdictMeta.fileNameColumnName} = ?;
      ''',
      [fileNameExt],
    );
    final metaStmt = db.prepare(
      '''
        INSERT INTO '${MdictMeta.tableName}' 
          (${MdictMeta.keyColumnName}, 
          ${MdictMeta.valueColumnName}, 
          ${MdictMeta.fileNameColumnName}
          ) 
        VALUES (?, ?, ?)
      ''',
    );
    for (final info in indexInfo.metaInfo.entries) {
      metaStmt.execute([info.key, info.value, fileNameExt]);
    }
    metaStmt.close();

    /// KEYS table
    final totalKeys = indexInfo.keyList.length;
    progressController?.add(
      MdictProgressReaderHelperBuildKey(fileNameExt, 0, totalKeys),
    );
    db.execute(
      '''
        DELETE FROM '${MdictKey.tableName}' 
        WHERE  ${MdictKey.fileNameColumnName} = ?;
      ''',
      [fileNameExt],
    );
    // SQLite SQLITE_MAX_VARIABLE_NUMBER = 32766
    // => We can insert 32766 / 4 ~ 8191 keys at a time
    const countsEachTime = 8191;
    final partitionedKeyIter = partition(indexInfo.keyList, countsEachTime);
    final statementMap = <int, CommonPreparedStatement>{};
    var insertedCount = 0;
    for (final keyList in partitionedKeyIter) {
      _insertKeys(
        db: db,
        keys: keyList,
        dictFileNameExt: fileNameExt,
        statementMap: statementMap,
      );
      insertedCount += keyList.length;
      progressController?.add(
        MdictProgressReaderHelperBuildKey(
          fileNameExt,
          insertedCount,
          totalKeys,
        ),
      );
    }
    for (final statement in statementMap.values) {
      statement.close();
    }

    /// RECORDS table
    progressController?.add(MdictProgressReaderHelperBuildRecord(fileNameExt));
    db.execute(
      '''
        DELETE FROM '${MdictRecord.tableName}' 
        WHERE  ${MdictRecord.fileNameColumnName} = ?;
      ''',
      [fileNameExt],
    );
    db.prepare(
        '''
        INSERT INTO ${MdictRecord.tableName} 
          (${MdictRecord.compressedSizeColumnName}, 
          ${MdictRecord.uncompressedSizeColumnName},
          ${MdictRecord.fileNameColumnName}
          ) 
        VALUES (?, ?, ?)
      ''',
      )
      ..execute([
        indexInfo.recordsCompressedSizes.buffer.asUint8List(),
        indexInfo.recordsUncompressedSizes.buffer.asUint8List(),
        fileNameExt,
      ])
      ..close();
    progressController?.add(
      MdictProgressReaderHelperFinishedIndex(fileNameExt),
    );
  }

  static Future<Map<String, String>> _getHeader({
    required String fileNameExt,
    required CommonDatabase db,
  }) async {
    final header = <String, String>{};
    final resultSet = db.select(
      '''
        SELECT ${MdictMeta.keyColumnName}, ${MdictMeta.valueColumnName} 
        FROM ${MdictMeta.tableName}
        WHERE ${MdictMeta.fileNameColumnName} = ?
      ''',
      [fileNameExt],
    );
    for (final row in resultSet) {
      header[row[MdictMeta.keyColumnName] as String] =
          row[MdictMeta.valueColumnName] as String;
    }
    return header;
  }

  static Future<List<Uint32List>> _getRecordList({
    required String fileNameExt,
    required CommonDatabase db,
  }) async {
    final resultSet = db.select(
      '''
        SELECT ${MdictRecord.compressedSizeColumnName}, ${MdictRecord.uncompressedSizeColumnName} 
        FROM ${MdictRecord.tableName} 
        WHERE ${MdictRecord.fileNameColumnName} = ?
      ''',
      [fileNameExt],
    );
    final row = resultSet.first;
    final compressedSizes =
        (row[MdictRecord.compressedSizeColumnName] as Uint8List).buffer
            .asUint32List();
    final uncompressedSizes =
        (row[MdictRecord.uncompressedSizeColumnName] as Uint8List).buffer
            .asUint32List();
    return [compressedSizes, uncompressedSizes];
  }

  static Future<MdictReader> init({
    required String filePath,
    required CommonDatabase db,
    StreamController<MdictProgress>? progressController,
  }) async {
    final fileNameExt = MdictHelpers.getFileNameWithExtensionFromPath(filePath);
    if (_mdictNotExistInDb(fileNameExt: fileNameExt, db: db)) {
      await _buildIndex(
        dictFilePath: filePath,
        fileNameExt: fileNameExt,
        db: db,
        progressController: progressController,
      );
    }
    progressController?.add(MdictProgressReaderHelperGetHeaders(fileNameExt));
    final header = await _getHeader(fileNameExt: fileNameExt, db: db);
    progressController?.add(
      MdictProgressReaderHelperGetRecordList(fileNameExt),
    );
    final recordSizes = await _getRecordList(fileNameExt: fileNameExt, db: db);
    progressController?.add(
      MdictProgressReaderHelperFinishedCreateDict(fileNameExt),
    );
    return MdictReader(
      path: filePath,
      fileName: fileNameExt,
      db: db,
      header: header,
      recordsCompressedSizes: recordSizes[0],
      recordsUncompressedSizes: recordSizes[1],
    );
  }
}
