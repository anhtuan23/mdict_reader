import 'package:mdict_reader/src/progress/mdict_progress.dart';

/// A helper class containing static factory methods to build standard
/// [MdictProgress] state updates for different dictionary operations.
abstract class MdictProgressHelper {
  // * DictWriterHelper

  /// Progress status when no MDX file is found in the import path.
  static MdictProgress copyDictNoMdx() => const MdictProgressCopyDictNoMdx();

  /// Progress status when a dictionary with [dictName] is being imported.
  static MdictProgress copyDictAddDictName(String dictName) =>
      MdictProgressCopyDictAddDictName(
        dictName,
      );

  /// Progress status when checking the version compatibility of [dictName].
  static MdictProgress copyDictCheckVersion(String dictName) =>
      MdictProgressCopyDictCheckVersion(
        dictName,
      );

  /// Error progress status when the version of [dictName] is not supported.
  static MdictProgress copyDictErrorVersion(String dictName) =>
      MdictProgressCopyDictErrorVersion(
        dictName,
      );

  /// Progress status when copying a dictionary file from [filePath].
  static MdictProgress copyDictCopyFile(String filePath) =>
      MdictProgressCopyDictCopyFile(
        filePath,
      );

  /// Progress status when adding [dictName] to the loaded dictionary list.
  static MdictProgress copyDictAddDictList(String dictName) =>
      MdictProgressCopyDictAddDictList(
        dictName,
      );

  /// Progress status when starting the deletion of [dictName].
  static MdictProgress deleteDictStart(String dictName) =>
      MdictProgressDeleteDictStart(
        dictName,
      );

  /// Error progress status when the dictionary [dictName] does not exist.
  static MdictProgress deleteDictNotExistError(String dictName) =>
      MdictProgressDeleteDictNotExistError(
        dictName,
      );
  // * MdictApi

  /// Finished initializing the core MDICT manager.
  static MdictProgress mdictApiFinishedInitManager() =>
      const MdictProgressApiFinishedInitManager();

  /// Finished inserting/importing the dictionary files.
  static MdictProgress mdictApiFinishedInsert() =>
      const MdictProgressApiFinishedInsert();

  /// Finished deleting the dictionary file.
  static MdictProgress mdictApiFinishedDelete() =>
      const MdictProgressApiFinishedDelete();

  /// Finished searching the dictionaries.
  static MdictProgress mdictApiFinishedSearch() =>
      const MdictProgressApiFinishedSearch();

  /// Finished executing a deeper definition lookup query.
  static MdictProgress mdictApiFinishedQuery() =>
      const MdictProgressApiFinishedQuery();

  /// Finished querying static resource files from the dictionary.
  static MdictProgress mdictApiFinishedQueryResource() =>
      const MdictProgressApiFinishedQueryResource();

  /// Finished reordering the dictionaries.
  static MdictProgress mdictApiFinishedReorder() =>
      const MdictProgressApiFinishedReorder();
}
