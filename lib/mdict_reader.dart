/// Support for reading mdict file.
///
/// Reader for mdict file
library;

// Native builds use the real isolate-backed manager. Browser builds use a
// same-isolate facade because web dictionary bytes and SQLite WASM state live
// in browser-managed storage that is not shared like native filesystem paths.
export 'src/isolated_manager/isolated_manager_web.dart'
    if (dart.library.io) 'src/isolated_manager/isolated_manager.dart';
export 'src/mdict_manager/mdict_manager.dart';
export 'src/mdict_manager/mdict_manager_models.dart';
export 'src/mdict_reader/mdict_reader.dart';
export 'src/platform/mdict_file_system.dart';
export 'src/progress/mdict_progress.dart';
export 'src/progress/mdict_progress_helper.dart';
export 'src/utils.dart';
