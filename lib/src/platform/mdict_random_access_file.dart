// Exposes the same random-access file API on native and browser platforms.
//
// Native platforms open real files with `dart:io`. Web builds cannot receive a
// host filesystem path from the browser, so they use logical references such as
// `idb://mdict/cedict/CC-CEDICT.mdx` that point to bytes stored in IndexedDB.
export 'mdict_random_access_file_stub.dart'
    if (dart.library.io) 'mdict_random_access_file_io.dart';
