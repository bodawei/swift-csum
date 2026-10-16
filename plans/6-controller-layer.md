# Plan 6: the Controller layer

## Goal

Give the application a real Controller layer: the module that owns filesystem access,
checksumming, diffing, and the `.csum.csv` file formats, expressed as typed data
structures rather than rows of strings. Per `AGENTS.md` this is "the application,
stripped of its head" — the View/ViewModel and the `csum-cli` View call into it and
carry no logic of their own.

The driving use case is a specific and practical one: **compare two `.csum.csv` files
whose roots differ.** A checksum file is taken of a tree at one location and describes
that tree. By the time it is compared, the same tree may live somewhere else — the
folder was moved or renamed, the archive was unpacked into a different directory, the
disk is mounted at a different mount point, or the file simply came from another
machine. Two such files describe the same content with entirely different absolute
paths.

The comparison must therefore answer "what actually changed in the files?" and not
"every path is different, so everything is moved". That requires three things, and they
are the reason for the shape of the model below: every entry stores an **absolute**
pathname; each result records **exactly one root**, so any path decomposes unambiguously
into root plus relative path; and the engine matches on that relative path, so a file
that stayed put inside a relocated tree is *unchanged*, a file that moved *within* the
tree is *moved*, and only genuine content differences are *changed*. Everything else in
this plan — dropping the multi-source overload, dropping per-source and per-entry
algorithms, keeping `root` on both the result and each comparison source — follows from
that requirement.

Two operations:

- `calculateChecksums(at:)` — checksum one file or folder; return metadata plus one
  entry per file (absolute pathname, checksum, creation time, modification time, size).
- `compare(first:second:)` — each side is a `.csum.csv` file or a file/folder checksummed
  on the spot; return metadata plus added / removed / changed / moved / renamed /
  unchanged, with the old **and** new entry for the paired sections.

Four format utilities:

- decode single-source `.csum.csv` text → `ChecksumResult`
- encode `ChecksumResult` → single-source `.csum.csv` text
- decode comparison text → `ComparisonResult`
- encode `ComparisonResult` → comparison text

## Naming and module layout

The module `ChecksumCore` is renamed `CsumController` — the module is the controller
layer, and the name should say so. Target, product, and directory all follow; the CLI
target stays `csum-cli`. (Spelled `CsumController`, not `CSumController`, to match the
existing `CsumCsvDataRow` / `CsumCLI` casing; say the word if you want the other.)

```
Sources/CsumController/
  Model/
    ChecksumAlgorithm.swift        (unchanged)
    ChecksumEntry.swift            one file's data, typed
    ChecksumResult.swift           ChecksumMetadata + [ChecksumEntry]
    ComparisonResult.swift         ComparisonMetadata + the six sections
    CsumFormat.swift               format version, writer/tool tokens, errors
  Controller/
    CsumController.swift           calculateChecksums / compare / loadChecksumResult
    ChecksumCollector.swift        filesystem walk + hashing  → [ChecksumEntry]  (internal)
    ComparisonEngine.swift         the diff algorithm        → the six sections  (internal)
    ChecksumCalculator.swift       (unchanged) raw CryptoKit streaming hash
  Format/
    Csv.swift                      (unchanged) RFC 4180 tokenizer/serializer
    ChecksumFileCodec.swift        parse/render a single-source .csum.csv
    ComparisonFileCodec.swift      parse/render a comparison
```

`CsumController`, the `Model` types, and the two codecs are public; `ChecksumCollector`
and `ComparisonEngine` become `internal`. `Tsv.swift` (Copy Rows) is a View-side helper
and stays as it is.

## Data model

### ChecksumEntry

```swift
public enum ChecksumFailureCode: Sendable, Equatable, Hashable {
    case cannotOpen
    case readFailed
}

public enum ChecksumOutcome: Sendable, Equatable, Hashable {
    case digest(String)
    case failure(ChecksumFailureCode)
}

public struct ChecksumEntry: Sendable, Equatable, Hashable {
    public var path: String
    public var outcome: ChecksumOutcome
    public var size: Int64
    public var created: Date?
    public var modified: Date?
}
```

- `path` is **always absolute**, canonical (symlinks and the `/var` firmlink resolved),
  so two entries that name the same file can be recognised as such. Display forms
  (`./…`, filename, basename) are the upper layers' business.
- No `algorithm` field: one algorithm per result (below).
- No `filename`, `checksumText`, `isFailure`, or `displayPath`. Those are derivations,
  and derivations for the head belong in the head.
- `outcome` distinguishes a digest from a failure by construction. `"Error: …"` no
  longer appears anywhere — failures are codes, and the View picks the words (item 5).

### ChecksumResult

```swift
public struct ChecksumMetadata: Sendable, Equatable {
    public var formatVersion: String
    public var writer: String
    public var toolVersion: String
    public var algorithm: ChecksumAlgorithm
    public var computedAt: Date
    public var root: String
}

public struct ChecksumResult: Sendable, Equatable {
    public var metadata: ChecksumMetadata
    public var entries: [ChecksumEntry]
}
```

Exactly one root. `root` is the absolute, canonical path of the picked item — the
folder, or the single file itself. Since every entry path is absolute and there is
exactly one root, every path is unambiguously decomposable into root + relative, which
is what makes "same file, different location" comparable (item 7). No `sources` array
and no multi-source overload.

### ComparisonResult

```swift
public struct MatchedEntry: Sendable, Equatable, Hashable {
    public var old: ChecksumEntry
    public var new: ChecksumEntry
}

public enum SourceKind: String, Sendable {
    case file, folder, csumFile
}

public struct ComparisonSource: Sendable, Equatable {
    public var path: String
    public var kind: SourceKind
    public var root: String
    public var computedAt: Date
}

public struct ComparisonMetadata: Sendable, Equatable {
    public var formatVersion: String
    public var writer: String
    public var toolVersion: String
    public var computedAt: Date
    public var algorithm: ChecksumAlgorithm
    public var first: ComparisonSource
    public var second: ComparisonSource
}

public struct ComparisonResult: Sendable, Equatable {
    public var metadata: ComparisonMetadata
    public var unchanged: [ChecksumEntry]
    public var added: [ChecksumEntry]
    public var removed: [ChecksumEntry]
    public var changed: [MatchedEntry]
    public var moved: [MatchedEntry]
    public var renamed: [MatchedEntry]
}
```

- `MatchedEntry.old` / `.new` are whole entries, so "old and new paths, old and new
  sizes, old and new times" are all reachable without parallel scalar fields.
- `ComparisonSource.path` is what the caller passed; `.root` is the root the entries are
  relative to. They differ when a side is a `.csum.csv` recorded against a different
  location, and keeping both is what lets the engine compare root-relative paths across
  a move of the whole tree.
- One `algorithm` for the whole comparison. No per-source algorithm: old and new must
  agree, and disagreeing is an error, not a field (item 8).
- No `isEmpty`, `count(of:)`, or section enum-for-display: the heads iterate the six
  arrays (item 9).

### Errors

```swift
public enum MalformedFileReason: Sendable, Equatable {
    case missingMetadata
    case unexpectedColumns(section: String, expected: Int, found: Int)
    case unparsableSize(section: String, row: Int)
    case unparsableTimestamp(section: String, row: Int)
    case unparsableOutcome(section: String, row: Int)
    case unterminatedQuote
}

public enum CsumError: Error, Sendable, Equatable {
    case notFound(path: String)
    case sourceUnreadable(path: String)
    case malformedFile(path: String, reason: MalformedFileReason)
    case unsupportedFormatVersion(found: String, expected: String)
    case algorithmMismatch(first: ChecksumAlgorithm, second: ChecksumAlgorithm)
}
```

Every case is data, none is a sentence. A per-file read failure during a walk is **not**
a thrown error — it becomes `ChecksumEntry.outcome = .failure(.cannotOpen)`, so one bad
file never aborts a batch. Only a source-level failure throws.

`algorithmMismatch` gets its own case rather than reusing `unsupportedFormatVersion`
(answer to the question): `unsupportedFormatVersion` is about the `# csum-format`
number, `algorithmMismatch` is about two results whose digests could never be
comparable. Silently comparing sha256 digests against sha1 digests would mark every file
changed, which is worse than refusing.

Where the algorithm comes from matters, because `compare` has no algorithm option. A
`.csum.csv` side records its algorithm in its metadata, and that record is authoritative:
any live side is checksummed with it, so a sha1 file compared against a folder at a new
location still matches. That leaves exactly one unresolvable case, and it is the only one
`algorithmMismatch` covers — two `.csum.csv` sides that recorded different algorithms.
When neither side is a file, the controller's configured algorithm is used. (An earlier
draft had the controller refuse a file/live disagreement instead of adopting the file's
algorithm; adoption is what makes the option unnecessary.)

## Controller operations

```swift
public struct CsumController: Sendable {
    public init(algorithm: ChecksumAlgorithm)

    public func calculateChecksums(
        at url: URL,
        progress: (@Sendable (Int, Int) -> Void)?
    ) throws -> ChecksumResult

    public func loadChecksumResult(at url: URL) throws -> ChecksumResult

    public func compare(first: URL, second: URL) throws -> ComparisonResult
}
```

- `calculateChecksums(at:)` — file → one entry; folder → recursive walk sorted by path,
  hidden files included, symlinks skipped, per-file failures as `.failure` entries.
  Metadata: `computedAt = Date()`, `algorithm` from the controller, `root` =
  canonical absolute path of `url`.
- `loadChecksumResult(at:)` — a `.csum.csv` is decoded by the codec; anything else is
  checksummed. The single URL overload covers the security-scoped access window; the
  multi-pick overload is dropped, so a View that wants several items holds several
  results (item 11).
- `compare(first:second:)` — load both sides; resolve the algorithm (a `.csum.csv`
  side's recorded algorithm wins, two file sides must agree or the call throws
  `algorithmMismatch`, otherwise the controller's configured algorithm); checksum any
  live side with it; run `ComparisonEngine`; and fill in `ComparisonMetadata`:
  `computedAt` now, the resolved `algorithm`, and one `ComparisonSource` per side
  (`path`, `kind`, `root`, `computedAt`).

The engine keeps today's matching rules: unchanged first (same root-relative path, same
checksum, same size), leftovers paired by checksum + size and split into renamed (same
parent directory) or moved, leftovers after that added or removed, each section sorted
by its output path. That logic is carried over from `CsvCompare` as-is; it has been
exercised very little, so treat it as unproven until the tests below pin it down.

## Text formats

Version 1.0. There is no prior format to support: the two `.csum.csv` files in existence
can be regenerated, so nothing is grandfathered and no legacy branch is written.

### Single source

```
# csum-format 1.0
# csum-writer csum-cli 1.0
# csum-computed 2026-10-16T04:14:00Z
# csum-algorithm sha256
# csum-root /Users/djb/Documents
Checksum,Size,Created,Modified,Path
3b1f…,1234,1750000000,1750000000,/Users/djb/Documents/a.txt
!cannotOpen,0,,,/Users/djb/Documents/sub/b.bin
```

- Paths absolute; the root lives in the metadata comment, so relative views are
  derivable and the file is self-describing.
- `Algorithm` and `Filename` columns are gone. `Filename` was derivable from `Path`, so
  it goes the same way as `Algorithm`.
- `Path` is last because it is the only field whose width varies wildly; keeping it off
  the front is what makes a column of rows readable by eye.
- Rows are `Checksum,Size,Created,Modified,Path`.
- `Checksum` is a lowercase hex digest, or `!` + failure code (`!cannotOpen`,
  `!readFailed`) — machine-readable, translatable, and it cannot collide with a digest.
- `Created` / `Modified` are Unix epoch seconds, empty when the file has no such date.
- Metadata timestamps are ISO-8601; row timestamps stay epoch seconds so the CSV remains
  spreadsheet-friendly. That asymmetry is deliberate.

### Comparison

```
# csum-format 1.0
# csum-writer csum-cli 1.0
# csum-computed 2026-10-16T04:14:00Z
# csum-algorithm sha256
# csum-first path=/Users/djb/old kind=folder root=/Users/djb/old computed=2026-10-16T04:14:00Z
# csum-second path=/Users/djb/new.csum.csv kind=csumFile root=/Users/djb/new computed=2026-10-15T09:00:00Z
# Added
Checksum,Size,Created,Modified,Path
…
# Removed
Checksum,Size,Created,Modified,Path
…
# Changed
Old Checksum,Old Size,Old Created,Old Modified,Old Path,New Checksum,New Size,New Created,New Modified,New Path
…
# Moved
Old Checksum,Old Size,Old Created,Old Modified,Old Path,New Checksum,New Size,New Created,New Modified,New Path
…
# Renamed
Old Checksum,Old Size,Old Created,Old Modified,Old Path,New Checksum,New Size,New Created,New Modified,New Path
…
# Unchanged
Checksum,Size,Created,Modified,Path
…
```

### Section schemas

Two shapes only, chosen by the section title — not by sniffing the column names:

| Section | Shape |
|---|---|
| `Added`, `Removed`, `Unchanged` | single entry — 5 columns |
| `Changed`, `Moved`, `Renamed` | old entry then new entry — 10 columns |

The decoder reads the `# <Title>` comment that opens a section, expects exactly the
column set for that title's shape, and throws `malformedFile` on anything else. To
answer the earlier question directly: this is **not** a version-free schema evolution
scheme. Adding a column changes the expected count, which is a hard error, which means a
format change requires bumping `csum-format`. If we ever want additive-without-bumping,
we would have to move to name-based column mapping deliberately — not by accident.

`# Moved` and `# Renamed` no longer share the old `Filename,Checksum,Size,From,To`
shape; they use the same 10-column old/new shape as `# Changed`, so all three paired
sections carry full old and new data in one form.

## Codecs

```swift
public enum ChecksumFileCodec {
    public static func parse(_ text: String) throws -> ChecksumResult
    public static func parse(contentsOf url: URL) throws -> ChecksumResult
    public static func render(_ result: ChecksumResult) -> String
}

public enum ComparisonFileCodec {
    public static func parse(_ text: String) throws -> ComparisonResult
    public static func parse(contentsOf url: URL) throws -> ComparisonResult
    public static func render(_ result: ComparisonResult, sections: [ComparisonSection]) -> String
}
```

`render` emits the BOM and the Excel CRLF line endings, matching what the app's
`CSVDocument` writes today. The comparison renderer takes the sections to write, which
is how the CLI flags and any future save filter are honoured without the codec knowing
about flags. `ComparisonSection` is an ordered list of the six kinds, used by the codec
and the CLI; it is not stored on the result.

## CLI

Two subcommands, matching the shape `AGENTS.md` already describes for the csum CLI
("check and compare subcommands"). Both take `<command> <subcommand> <options>
<arguments>`, and the README examples are written in that order.

```
csum-cli check <path> [-a <algorithm>]
csum-cli compare <first> <second> [-a] [-d] [-c] [-m] [-r] [-u]
```

- `check` — one file or directory, writes the single-source `.csum.csv` to stdout.
  `-a/--algorithm` selects sha256 (default), sha1, or md5.
- `compare` — two arguments, each a `.csum.csv` file or a file/directory which is
  checksummed on the spot. Writes the comparison format to stdout.
- `compare` takes no algorithm option. A `.csum.csv` side already records the algorithm
  it was made with, and that is what any live side is checksummed with, so
  `compare old.csum.csv <moved folder>` works whatever the folder's algorithm would have
  been by default. Only when neither side is a file does the default (sha256) apply.
- Section flags: `-a/--added`, `-d/--removed` (was `--deleted`), `-c/--changed` (was
  `--modified`), `-m/--moved` (was `-o`), `-r/--renamed`, `-u/--unchanged`. Without any,
  added/removed/changed/moved/renamed print and unchanged does not. Long names match the
  section titles, and every short letter is the first letter of its long name except
  `-d/--removed`, where `-r` is taken by renamed. `-a` means algorithm on `check` and
  added on `compare`; the two never meet.
- Errors go to stderr with a non-zero exit, from `CsumError` — the CLI renders the same
  codes the GUI would.
- The old positional `[<path>] [<path>]` form is removed.

## Retired and migrated

| Goes away | Replaced by |
|---|---|
| `CsumCsvDataRow` | `ChecksumEntry` + codec column mapping |
| `ChecksumTable` / `TableData` mapping | `TableData` stays; the row mapping is internal to the codecs |
| `CsvCompare` | `CsumController.loadChecksumResult` + `ComparisonEngine` |
| `CsvFormattingUtils` | `ChecksumFileCodec` / `ComparisonFileCodec` |
| `MovedPair` / `ChangedPair` | `MatchedEntry` |
| `ComparisonReport` | `ComparisonResult` |
| `ChecksumCollector.collectAll(urls:)` | dropped |
| `ChecksumCore` | `CsumController` |

Only `Sources/csum-cli/main.swift` is rewritten in this pass, into the two subcommands.

## Platform

The controller uses Foundation and CryptoKit plus `realpath` from the Darwin C library.
None of that is macOS-only — CryptoKit, `FileManager.enumerator`, `FileHandle`,
`URLResourceKey.creationDateKey`, security-scoped URLs, and `realpath` are all present on
iOS. It compiles for both platforms with no `#if os(macOS)` anywhere, so "no iOS-specific
code" also means "no macOS-specific code": it is plain Darwin. Linux would need a
`Glibc` branch, which is moot given `Package.swift` declares macOS 13 and iOS 13.

## Test plan

Per `AGENTS.md`: integration tests of the controller, e2e through the CLI. A test target
is added to `Package.swift`:
`.testTarget(name: "CsumControllerTests", dependencies: ["CsumController"])`. It uses
XCTest — the manifest is `swift-tools-version:5.9`, and Apple's swift-testing framework
(`import Testing`) needs a 6.0 manifest and toolchain, so using it would mean bumping the
tools version first. XCTest needs nothing. If we ever move the manifest to 6.0 we can
switch. No GUI tests in this pass.

Helpers: `makeTempTree(spec:)` builds a directory from a literal description;
`makeFile(at:contents:created:modified:)` writes bytes and sets creation/modification
dates explicitly with `FileManager.setAttributes([.creationDate, .modificationDate])`, so
assertions do not depend on the clock. Every test cleans up its temp tree.

### 1. `calculateChecksums` integration

- single file, single folder, folder nested three levels deep — one entry per file,
  sorted by path, every `path` absolute and canonical;
- hidden files included; symlinks (including one pointing at an ancestor) skipped, no
  infinite recursion;
- an unreadable file yields `.failure(.cannotOpen)` and the batch still completes;
- empty folder yields zero entries and valid metadata;
- metadata: `root` is the canonical picked path, `computedAt` within a second of the
  call, `algorithm` is what the controller was built with, format/writer/tool tokens are
  the constants;
- contents matching `shasum -a 256` output, including a multi-megabyte binary (exercises
  the 1 MB chunk loop), plus `sha1` and `md5` against `shasum -a 1` and `md5`;
- a path with spaces, quotes, a comma, a newline, and non-ASCII characters survives the
  walk and the codec.

### 2. `compare` integration

One small tree per section, plus one combined tree exercising all six at once:

- `compare(A, A)` — all unchanged, the other five empty;
- added only, removed only, changed only, moved (same checksum/size, new directory),
  renamed (same directory, new name), case-only rename;
- a changed entry reports the right old and new `path`, `size`, and `modified`;
- both sides against both kinds: `.csum.csv` vs folder, folder vs folder, file vs file,
  `.csum.csv` vs `.csum.csv`;
- the goal itself: take a `.csum.csv` of a tree at one location, move the whole tree to a
  different location, compare the file against the new location — every entry is
  unchanged, `metadata.first.root` and `metadata.second.root` differ, and the added,
  removed, moved, renamed, and changed sections are all empty;
- two byte-identical files in one source pair deterministically with two byte-identical
  files in the other, run repeatedly — the pairing must not depend on dictionary order;
- a `.csum.csv` written with `-a sha1` compared against a live folder yields unchanged
  entries: the live side is checksummed with the file's recorded sha1, not with the
  controller's configured algorithm;
- two `.csum.csv` sides recorded with different algorithms throw `algorithmMismatch`;
  two live sides use the controller's configured algorithm; a missing source throws
  `notFound`;
  a truncated or nonsense `.csum.csv` throws `malformedFile` with the right reason.

### 3. Codec round trips (no filesystem)

- `parse(render(x)) == x` for a `ChecksumResult` covering digests and every failure code,
  `nil` and non-`nil` dates, and paths containing commas, quotes, newlines, leading and
  trailing spaces, and non-ASCII characters;
- `parse(render(x)) == x` for a `ComparisonResult` with all six sections populated;
- `render(parse(text)) == text` for canonical text (idempotence);
- BOM and CRLF are consumed on parse and re-emitted on render;
- `render(_, sections:)` writes exactly the requested sections in canonical order and
  omits empty ones;
- epoch-second truncation is pinned: `…:00.750` comes back as `…:00`, and round-trip
  comparisons of dates are at second granularity;
- each malformed input produces the specific `MalformedFileReason`: missing
  `# csum-format`, wrong column count for a section title, a size that is not a number, a
  timestamp that is not a number, a checksum cell that is neither hex nor `!code`, an
  unterminated quote, and `# csum-format 2.0` → `unsupportedFormatVersion`.

### 4. CLI e2e

A `Tests/e2e.sh` against the built binary (`swift test` cannot conveniently exec the
product):

- `check <file>` and `check <folder>` — stdout parses through `ChecksumFileCodec` and
  every digest equals `shasum -a 256`;
- `check -a sha1` and `check -a md5` agree with `shasum -a 1` and `md5`;
- `check -a sha1 <folder>` then `compare <that .csum.csv> <a copy of the folder at
  another path>` reports everything unchanged with no algorithm option on the compare
  side, and the metadata line records `sha1`;
- the round trip that matters most: `check <folder> > x.csum.csv`, then
  `compare x.csum.csv <same folder>` reports everything unchanged;
- the goal end to end: `check <folder> > x.csum.csv`, move the folder somewhere else,
  `compare x.csum.csv <moved folder>` reports everything unchanged;
- `compare` with no flags prints added/removed/changed/moved/renamed and no unchanged;
  with `-u` it includes unchanged; with a single flag it prints only that section;
- `compare` output parses through `ComparisonFileCodec`;
- missing path, unparsable `.csum.csv`, and a `check` against a nonexistent file all exit
  non-zero with stderr text;
- `csum-cli --help` lists `check` and `compare`; `csum-cli check --help` documents `-a`.

### Verification commands

```
swift build
swift test
bash Tests/e2e.sh
```

### Sequencing

1. Rename the module, move files into `Model/` / `Controller/` / `Format/`, add the test
   target. `swift build` should still fail only where the CLI and app are not yet
   updated.
2. Model types; `ChecksumCollector` returns `[ChecksumEntry]`; `calculateChecksums`;
   tests group 1.
3. `ChecksumFileCodec` + tests group 3 (single-source half); CLI `check`.
4. `ComparisonEngine` + `ComparisonResult`; `ComparisonFileCodec` + tests group 3 (pair
   half) and group 2; CLI `compare`.
5. Delete the retired types, keeping `Csv.swift` and `Tsv.swift`.
6. `Tests/e2e.sh`, README rewrite (subcommand order, new columns, new formats).

The app target is **not** touched in this pass: `csum/*.swift` still `import
ChecksumCore` and use the retired types, so the Xcode build breaks at step 1 and stays
broken until the GUI revision adopts `CsumController`, the following day. The Xcode
project's local package product reference is updated in that pass too.

## Settled

- `Filename` and `Algorithm` columns dropped; rows are `Checksum,Size,Created,Modified,
  Path`, with the variable-width path last for legibility.
- Absolute paths everywhere in the model, one `root` per result, root-relative matching
  in the engine.
- CLI becomes `check` / `compare` subcommands; breaking change accepted. `check` takes
  `-a/--algorithm`; `compare` takes none, adopting the algorithm the `.csum.csv` side
  recorded. Compare section flags are `-a -d -c -m -r -u`, each the first letter of its
  long name except `-d` for removed.
- No multi-source overload.
- No `ComparisonSection` on the result; the ordered list exists only for the codec and
  the CLI.
- Failures are codes; no human strings in the controller. `!<code>` in the checksum cell.
- Module renamed `CsumController`; the app target stays broken until the GUI revision.
- Structured `# csum-*` comments; single format version 1.0; no legacy reading.
