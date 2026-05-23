# Mdict Reader Context

Last researched: 2026-05-22.

`mdict_reader` is a Dart package for reading MDX/MDD dictionary files and
querying them directly or through an isolate.

## Role

Readdict uses this package for local dictionary management, search, definition
lookup, and dictionary resource lookup such as images or audio from MDD files.

## Package Shape

- Package name: `mdict_reader`.
- Publish status: `none`.
- Current version: `0.0.1`.
- Dart SDK constraint: `>=2.17.0 <3.0.0`.
- Lints: `very_good_analysis` with local relaxations.
- Public library: `lib/mdict_reader.dart`.
- Public exports:
  - `IsolatedManager`.
  - `MdictManager`.
  - manager models.
  - lower-level reader API.
  - utility helpers.
- Important local path dependency: `../japanese_conjugation`.

The `japanese_conjugation` directory is present in this workspace, and its
`pubspec.yaml` package name matches the dependency key.

## Core Flow

- `MdictManager.create` opens SQLite, creates metadata/key/record tables, builds
  or reuses dictionary data, and returns a manager for search/query operations.
- `MdictDictionary` owns lower-level MDX/MDD file parsing and dictionary access.
- `IsolatedManager` spawns an isolate, initializes `MdictManager` there, sends
  typed request objects, and correlates typed result objects back to callers.
- SQLite tables and indexes are created inside `MdictManager.createTables`.
- Old dictionary rows are discarded when the current dictionary file list no
  longer includes them.
- v1 mdict files are explicitly not supported because lzo compression support is
  missing in Dart.

## Data And Tests

- Test assets include MDX/MDD dictionaries, CSS, images, UTF-16 data, sound
  data, and file names with special characters.
- Tests live under `test/src/` and cover reader, dictionary, manager, isolated
  manager, and helper behavior.
- `dict/` contains bundled dictionary files tracked by the repository.
- `bin/example.dart` is an example entrypoint; `bin/convert_mdx_v1_to_v2.md`
  documents a conversion path.

## Modernization Guidance

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
