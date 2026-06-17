import 'package:mdict_reader/src/progress/mdict_progress.dart';

/// Extension to format [MdictProgress] messages into user-friendly
/// display text.
extension MdictProgressDisplay on MdictProgress {
  /// Converts the progress message type and optional info list to a
  /// clean string.
  String toUserString() {
    return switch (this) {
      MdictProgressEmpty() => 'Ready',
      MdictProgressError(:final error) => 'Error: $error',
      MdictProgressCopyDictNoMdx() => 'No MDX file found',
      MdictProgressCopyDictAddDictName(:final dictName) =>
        'Adding dictionary $dictName...',
      MdictProgressCopyDictCheckVersion(:final dictName) =>
        'Checking version of $dictName...',
      MdictProgressCopyDictErrorVersion(:final dictName) =>
        'Unsupported version for $dictName',
      MdictProgressCopyDictCopyFile(:final filePath) => 'Copying $filePath...',
      MdictProgressCopyDictAddDictList(:final dictName) =>
        'Registering $dictName...',
      MdictProgressDeleteDictStart(:final dictName) => 'Deleting $dictName...',
      MdictProgressDeleteDictNotExistError(:final dictName) =>
        'Dictionary $dictName does not exist',
      MdictProgressApiFinishedInitManager() => 'Initialized',
      MdictProgressApiFinishedInsert() => 'Import complete',
      MdictProgressApiFinishedDelete() => 'Delete complete',
      MdictProgressApiFinishedSearch() => 'Search complete',
      MdictProgressApiFinishedQuery() => 'Lookup complete',
      MdictProgressApiFinishedQueryResource() => 'Resource loaded',
      MdictProgressApiFinishedReorder() => 'Reordered',
      MdictProgressManagerOpenDb() => 'Opening dictionary database...',
      MdictProgressManagerCreateMeta() => 'Setting up metadata...',
      MdictProgressManagerCountOld() => 'Counting old entries... ',
      MdictProgressManagerHasOld() => 'Found existing records.',
      MdictProgressManagerDiscardOld() => 'Discarding old table...',
      MdictProgressManagerCreateKey() => 'Creating keys...',
      MdictProgressManagerCreateRecord() => 'Creating records...',
      MdictProgressManagerProcessing(:final mdxFileNameExt) =>
        'Processing $mdxFileNameExt...',
      MdictProgressManagerQuerying(:final word) => 'Querying $word...',
      MdictProgressManagerFinishedQuerying() => 'Query complete',
      MdictProgressDictionaryProcessing(
        :final fileNameExt,
        :final fileExtension,
      ) =>
        'Processing $fileNameExt ($fileExtension)...',
      MdictProgressDictionaryGetCss() => 'Extracting stylesheet...',
      MdictProgressDictionaryCreatedDict() => 'Dictionary created',
      MdictProgressReaderHelperGetInfo() => 'Reading metadata...',
      MdictProgressReaderHelperReadHeader() => 'Reading header...',
      MdictProgressReaderHelperReadKeys() => 'Reading keys...',
      MdictProgressReaderHelperReadRecords() => 'Reading records...',
      MdictProgressReaderHelperBuildMeta() => 'Building metadata...',
      MdictProgressReaderHelperBuildKey(
        :final insertedCount,
        :final totalKeys,
      ) =>
        'Building keys ($insertedCount/$totalKeys)...',
      MdictProgressReaderHelperBuildRecord() => 'Building records...',
      MdictProgressReaderHelperFinishedIndex(:final fileNameExt) =>
        'Finished indexing $fileNameExt',
      MdictProgressReaderHelperGetHeaders() => 'Extracting headers...',
      MdictProgressReaderHelperGetRecordList() => 'Extracting records...',
      MdictProgressReaderHelperFinishedCreateDict(:final fileNameExt) =>
        'Finished loading $fileNameExt',
    };
  }
}
