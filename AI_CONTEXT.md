# Mdict Reader Context

Last researched: 2026-05-25.

`mdict_reader` is a Dart package for reading MDX/MDD dictionary files and
querying them directly or through an isolate.

## Role

Readdict uses this package for local dictionary management, search, definition
lookup, and dictionary resource lookup such as images or audio from MDD files.

## Package Shape

- Package name: `mdict_reader`.
- Publish status: `none`.
- Current version: `0.0.1`.
- Dart SDK constraint: `^3.0.0`.
- Lints: `very_good_analysis ^10.2.0` with local relaxations.
- Public library: `lib/mdict_reader.dart`.
- Public exports:
  - `IsolatedManager` through a conditional export. Native builds use the
    isolate-backed implementation; web builds use a same-isolate facade because
    the browser path cannot share the native isolate and file APIs.
  - `MdictManager`.
  - manager models.
  - lower-level reader API.
  - browser file-reference helpers for storing selected MDX/MDD/CSS bytes.
  - utility helpers.
- Important local path dependency: `../japanese_conjugation`.

The `japanese_conjugation` directory is present in this workspace, and its
`pubspec.yaml` package name matches the dependency key.

## Core Flow

- `MdictManager.create` takes an injected `CommonDatabase` and `MdictFileSystem` to build dictionary indexes.
- Database and file system abstractions are completely constructor-injected. Native builds use native `sqlite3` and `IoMdictFileSystem` inside the background isolate; web builds use standard browser OPFS (via `WebMdictFileSystem`) and SQLite WASM.
- `MdictDictionary` owns lower-level MDX/MDD file parsing and dictionary access via the injected `MdictFileSystem`.
- `IsolatedManager` spawns an isolate, initializes `MdictManager` there, sends
  typed request objects, and correlates typed result objects back to callers.
- SQLite tables and indexes are created inside `MdictManager.createTables`.
- Old dictionary rows are discarded when the current dictionary file list no
  longer includes them.
- v1 and v2 mdict files are supported in the core reader. v1 files use
  version-aware 32-bit stream sizes and the local Dart LZO1X block
  decompressor.

## Data And Tests

- Test assets include MDX/MDD dictionaries, CSS, images, UTF-16 data, sound
  data, and file names with special characters.
- Tests live under `test/src/` and cover reader, dictionary, manager, isolated
  manager, and helper behavior.
- `dict/` contains bundled dictionary files tracked by the repository.
- `bin/example.dart` is an example entrypoint; `bin/convert_mdx_v1_to_v2.md`
  documents a conversion path.

## Modernization Guidance

- Dependency modernization on 2026-05-23 moved this package to current Dart 3
  compatible constraints: `pointycastle ^4.0.0`, `sqlite3 ^3.3.1`,
  `equatable ^2.0.8`, `html ^0.15.6`, `path ^1.9.1`, `quiver ^3.2.2`,
  `test ^1.31.1`, and `very_good_analysis ^10.2.0`.
- `sqlite3` 3.x uses Dart native assets for platform library selection. Do not
  reintroduce the old `package:sqlite3/open.dart` override hook; that file was
  removed upstream and native assets now handle the local SQLite library.
- Web support depends on `package:sqlite3/wasm.dart`,
  `package:sqlite3/common.dart` interfaces, `archive` for zlib decoding
  without `dart:io`, and browser OPFS for browser MDX/MDD byte storage.
- File-writing and deleting helpers reside in `mdict_flutter`. `mdict_reader`
  is a 100% read-only engine.
- `dart pub outdated` still reports non-upgradable transitive native-assets
  packages through `sqlite3` (`code_assets`, `hooks`, and
  `native_toolchain_c`). Those are upstream transitive constraints, not direct
  package dependencies.
- SDK modernization should include `japanese_conjugation` validation because
  dictionary behavior depends on that package.
- Treat SQLite schema, row cleanup, MDX/MDD parsing, resource lookup, and isolate
  result correlation as high-risk behavior.
- Keep tests fixture-based. Add dictionary fixture coverage before changing
  parsing, encoding, decompression, or SQL behavior.
- Be careful with binary test assets and dictionary files; do not reformat or
  regenerate them incidentally.

## Validation

Run from `mdict_reader/`:

- `dart pub get`
- `dart format .`
- `dart analyze`
- `dart test`
