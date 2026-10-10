# swift-csum

Compute file checksums (SHA-256, SHA-1, or MD5) with a SwiftUI app on iPhone, iPad, and
Mac, or from the command line. Both front-ends share one hashing implementation
(`Sources/ChecksumCore`), which streams files in 1 MB chunks.

## App

Open `csum.xcodeproj` in Xcode and run the `csum` scheme. Selecting the "Mac"
destination runs the same app on your Mac — no separate macOS target needed.

Pick the algorithm from the dropdown — on Mac it sits inside the file-open dialog; on
iPhone/iPad it's the dropdown by the button and remembers your last choice. Choose
files with **Choose Files…** or a folder with **Choose Folder…** (the system picker
can't mix the two in one dialog). Folders are checksummed recursively — every file at
every depth gets a row (hidden files included), sorted by path; a file that can't be
read gets `Error: <details>` in its checksum cell instead of a digest. The result is a
table with column headings and visible cell boundaries, scrolled as needed, plus a
Copy Rows button that copies every row as a tab-separated line (paste-ready for a
spreadsheet):

| Filename | Checksum | Algorithm | Size | Created | Modified | Path |
|----------|----------|-----------|------|---------|----------|------|

- `Filename` — the file's name.
- `Checksum` — lowercase hex digest.
- `Algorithm` — `sha256`, `sha1`, or `md5`.
- `Size` — size in bytes.
- `Created` / `Modified` — creation and modification dates as Unix epoch seconds
  (long integers); empty if the file has no such date.
- `Path` — the file's full path.

If the checksum or path is wider than the window, the table scrolls horizontally.

Notes:

- To run on a real device or distribute the Mac build, set a Development Team under
  Signing & Capabilities. Simulator builds need no signing.
- The bundle identifier `com.djb.csum` is a placeholder — change it in the target's
  Signing & Capabilities settings.

## Command line

```
swift run csum-cli <path> [--algorithm <algorithm>]
```

- `<path>` — full path to the file (required positional argument).
- `-a, --algorithm` — `sha256` (default), `sha1`, or `md5`.

The tool prints only the lowercase hex digest to stdout. Errors are written to stderr
with a non-zero exit code.

Examples:

```
swift run csum-cli ~/Downloads/archive.zip
swift run csum-cli -a md5 ~/Downloads/archive.zip
```

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
csum-cli ~/Downloads/archive.zip
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

Using these from Finder:

- Double-clicking the raw `csum-cli` executable opens a Terminal window, but with no
  arguments it just prints usage and exits — it wants arguments, so the CLI is a
  Terminal tool.
- The Finder-facing tool is the GUI app: pick a file and it reports name, path, and
  checksum.
- To get "drop a file, get a checksum," make a droplet with Automator: New →
  Application → add a Run Shell Script action, set "Pass input: as arguments", body:
  ```
  for f in "$@"; do
    /usr/local/bin/csum-cli "$f"
  done
  ```
  Save as `csum-drop.app` and drop files onto it (pipe through `pbcopy` or show an
  `osascript` dialog if you want the result captured instead of printed).

## Layout

```
Sources/ChecksumCore/    shared hashing library (CryptoKit)
Sources/csum-cli/        command-line tool (swift-argument-parser)
csum.xcodeproj/          SwiftUI app project (iPhone, iPad, Mac)
csum/                    app sources
plans/                   project plans
```
