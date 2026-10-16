# swift-csum

Compute file checksums (SHA-256, SHA-1, or MD5) with a SwiftUI app on iPhone, iPad, and
Mac, or from the command line. Both front-ends share one hashing implementation
(`Sources/ChecksumCore`), which streams files in 1 MB chunks.

## App

Open `csum.xcodeproj` in Xcode and run the `csum` scheme. Selecting the "Mac"
destination runs the same app on your Mac — no separate macOS target needed.

The start screen has **Checksum File** and **Checksum Folder** buttons — pick the
algorithm from the dropdown (on Mac it sits inside the open dialog; on iPhone/iPad it's
the dropdown by the buttons and remembers your last choice). You can also drag files
and folders from Finder and drop them straight onto these buttons (or onto the compare
form's buttons — the `.csum.csv` buttons accept only `.csum.csv` files); dropped items
are handled exactly as if picked in the file dialog. Folders are checksummed
recursively — every file at every depth gets a row (hidden files included), sorted by
path, with paths shown relative to the picked folder as `./…`; a file that can't be read
gets `Error: <details>` in its checksum cell instead of a digest.

The result is a table with column headings and visible cell boundaries, scrolled as
needed, plus **Copy Rows** (tab-separated lines, paste-ready for a spreadsheet) and
**Save CSV…** (an Excel-ready `checksums.csum.csv` — RFC 4180 quoting, CRLF line
endings, UTF-8 BOM — starting with two `#` comment lines recording the app/version, the
source path(s), and the ISO-8601 date):

| Filename | Checksum | Algorithm | Size | Created | Modified | Path |
|----------|----------|-----------|------|---------|----------|------|

- `Filename` — the file's name.
- `Checksum` — lowercase hex digest.
- `Algorithm` — `sha256`, `sha1`, or `md5`.
- `Size` — size in bytes.
- `Created` / `Modified` — creation and modification dates as Unix epoch seconds
  (long integers); empty if the file has no such date.
- `Path` — the file's path (`./…` relative for folder picks).

### Comparing

The compare form has two rows; each row takes either a saved `.csum.csv`
(**Choose .csum.csv**) or a folder (**Choose Folder** — its checksums are computed on
the spot, with the current algorithm). Once both rows show their pick, **Compare**
enables and groups every entry into color-labeled sections: **Unchanged** (same path,
hash, and size), **Added** (only in the second source), **Removed** (only in the
first), **Moved** (same hash and size in a different directory, shown from → to),
**Renamed** (same hash and size in the same directory under a different name, shown
from → to), and **Changed** (same path, different hash or size, old and new side by
side). Unchanged entries are discounted first, then the remaining entries are paired up
as Moved or Renamed; anything left over is Added or Removed. Double-clicking a
`.csum.csv` file in Finder drops it into the first row, ready for a second source.

Notes:

- To run on a real device or distribute the Mac build, set a Development Team under
  Signing & Capabilities. Simulator builds need no signing.
- The bundle identifier `com.djb.csum` is a placeholder — change it in the target's
  Signing & Capabilities settings.

## Command line

```
swift run csum-cli <path> [<path>] [-c <algorithm>] [-u] [-d] [-a] [-m] [-o] [-r]
```

- **One path** — a file or directory: computes checksums and writes the complete
  checksum file (comments, header, rows) to stdout; redirect to save:
  `swift run csum-cli ~/Documents > docs.csum.csv`. Section flags are ignored here.
- **Two paths** — compares them. Each side may be a `.csum.csv` file or a
  file/directory (computed on the spot).
- Output is grouped into sections, each led by a `#` comment title. Added, Deleted,
  Modified, and Unchanged use the standard CSV header; Moved and Renamed use a
  `Filename,Checksum,Size,From,To` header. Default output is `# Added`, `# Deleted`,
  `# Moved`, `# Renamed`, `# Modified` (in that order); empty sections are skipped.
  Unchanged entries are omitted by default.
- `-u`, `-d`, `-a`, `-m`, `-o`, `-r` select exactly which sections print (if any is
  given); without them, Added/Deleted/Moved/Renamed/Modified print.
- `-c`/`--algorithm` — `sha256` (default), `sha1`, or `md5`, used when computing.

Errors are written to stderr with a non-zero exit code.

## Building

`swift build` builds only the Swift package (the CLI and the shared library) — it does
not build the app. The executable lands next to `Package.swift`:

- `swift build` → `.build/debug/csum-cli` (debug)
- `swift build -c release` → `.build/release/csum-cli` (optimized)

The app is built by Xcode instead, into DerivedData, for example:

```
~/Library/Developer/Xcode/DerivedData/csum-*/Build/Products/
    Debug-iphonesimulator/csum.app
    Debug-maccatalyst/csum.app
```

## Standalone executables

The release CLI is a standalone binary: it links only against macOS system libraries
(the Swift runtime, Foundation, CryptoKit) and needs no Xcode or toolchain installed.
It runs on macOS 13 or newer.

```
swift build -c release
sudo cp .build/release/csum-cli /usr/local/bin/    # or: mkdir -p ~/bin && cp .build/release/csum-cli ~/bin/
csum-cli ~/Downloads/archive.zip > archive.csum.csv
```

For a universal binary (Apple silicon and Intel):

```
swift build -c release --arch arm64 --arch x86_64
```

A standalone `.app` bundle for the Mac:

```
xcodebuild -project csum.xcodeproj -scheme csum -configuration Release \
    -destination 'generic/platform=macOS,variant=Mac Catalyst' \
    CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/csum-build build
cp -R /tmp/csum-build/Build/Products/Release-maccatalyst/csum.app ~/Desktop/
```

An unsigned, locally built `.app` runs fine on your own Mac — Gatekeeper only
scrutinizes downloaded (quarantined) files. For anyone else's Mac, either let Xcode
sign it with your Development Team, or share the repo and have them build it.

## Layout

```
Sources/ChecksumCore/    shared hashing library + CSV model/compare (CryptoKit)
Sources/csum-cli/        command-line tool (swift-argument-parser)
csum.xcodeproj/          SwiftUI app project (iPhone, iPad, Mac)
csum/                    app sources
plans/                   project plans
```
