# swift-csum

Compute file checksums (SHA-256, SHA-1, or MD5) with a SwiftUI app on iPhone, iPad, and
Mac, or from the command line. Both front-ends are thin: the filesystem walk, the
checksumming, the diff, and the `.csum.csv` reader and writer all live in one controller
layer (`Sources/CsumController`), which streams files in 1 MB chunks.

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
path; a file that cannot be read gets a failure code in its checksum cell instead of a
digest, and the run carries on.

The result is a table with column headings and visible cell boundaries, scrolled as
needed, plus **Copy Rows** (tab-separated lines, paste-ready for a spreadsheet) and
**Save CSV…** (an Excel-ready `checksums.csum.csv` — RFC 4180 quoting, CRLF line
endings, UTF-8 BOM — led by five `# csum-…` comment lines carrying the format version,
the tool, the ISO-8601 date, the algorithm, and the root the paths are relative to):

| Checksum | Size | Created | Modified | Path |
|----------|------|---------|----------|------|

- `Checksum` — lowercase hex digest, or `!cannotOpen` / `!readFailed` if the file could
  not be read.
- `Size` — size in bytes.
- `Created` / `Modified` — creation and modification dates as Unix epoch seconds
  (long integers); empty if the file has no such date.
- `Path` — the file's absolute path. It is last because it is the only field whose width
  varies wildly: a table of rows is far easier to read with the path out of the way.

Paths are stored absolute and the root is recorded separately, so a checksum file taken
before the tree was moved still compares as unchanged afterwards.

### Comparing

The compare form has two rows; each row takes either a saved `.csum.csv`
(**Choose .csum.csv**) or a folder (**Choose Folder**). Once both rows show their pick,
**Compare** enables and groups every entry into color-labeled sections: **Unchanged**,
**Added**, **Removed**, **Moved**, **Renamed**, and **Changed** — with old and new path,
size, and times side by side for the last three. Double-clicking a `.csum.csv` file in
Finder drops it into the first row, ready for a second source.

Notes:

- To run on a real device or distribute the Mac build, set a Development Team under
  Signing & Capabilities. Simulator builds need no signing.
- The bundle identifier `com.djb.csum` is a placeholder — change it in the target's
  Signing & Capabilities settings.
- The app is being moved onto the new controller layer described below; until that
  lands, build the command-line tool.

## Command line

```
swift run csum-cli check <path> [-a <algorithm>]
swift run csum-cli compare <first> <second> [-a] [-d] [-c] [-m] [-r] [-u]
```

### `check`

One file or directory: writes the complete checksum file (comments, header, rows) to
stdout; redirect to save:

```
swift run csum-cli check ~/Documents > docs.csum.csv
swift run csum-cli check -a sha1 ~/Documents > docs.csum.csv
```

`-a`/`--algorithm` selects `sha256` (default), `sha1`, or `md5`.

Folders are checksummed recursively — every file at every depth (hidden files included),
sorted by path. A file that cannot be read is recorded as `!cannotOpen` or `!readFailed`
rather than failing the run.

### `compare`

Two sources, each a saved `.csum.csv` file, a file, or a directory (checksummed on the
spot). Output is grouped into sections, each led by a `#` comment title:

- **Added**, **Removed**, and **Unchanged** use the same five columns as `check`.
- **Changed**, **Moved**, and **Renamed** use those five columns twice, prefixed `Old`
  and `New`, so both sides of the change are present: old and new path, size, and times.

```
swift run csum-cli compare ~/Documents docs.csum.csv
swift run csum-cli compare -u old.csum.csv /Volumes/Backup/Documents
```

- `-a -d -c -m -r -u` select added, removed, changed, moved, renamed, and unchanged.
  Without any of them, everything except unchanged prints.
- There is no algorithm option: a saved `.csum.csv` records the algorithm it was made
  with, and that is what the other side is checksummed with. Comparing two saved files
  that disagree is an error, and so is comparing two live sources without one.
- Because matching is on the path relative to each side's root, a folder that has moved
  since its checksums were taken compares as unchanged rather than as all-moved. That is
  the case the whole file format is designed around.

Errors go to stderr with a non-zero exit code.

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

### Testing

```
swift test        # the controller: checksumming, the diff, the readers and writers
bash Tests/e2e.sh # the CLI against shasum, on a temporary tree
```

## Standalone executables

The release CLI is a standalone binary: it links only against macOS system libraries
(the Swift runtime, Foundation, CryptoKit) and needs no Xcode or toolchain installed.
It runs on macOS 13 or newer.

```
swift build -c release
sudo cp .build/release/csum-cli /usr/local/bin/    # or: mkdir -p ~/bin && cp .build/release/csum-cli ~/bin/
csum-cli check ~/Downloads/archive.zip > archive.csum.csv
csum-cli compare archive.csum.csv ~/Downloads/archive.zip
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
Sources/CsumController/  the controller layer
  Model/                 checksum and comparison data structures, errors
  Controller/            checksumming, the filesystem walk, and the diff engine
  Format/                the .csum.csv reader and writer, and the CSV primitive
Sources/csum-cli/        command-line tool (swift-argument-parser)
csum.xcodeproj/          SwiftUI app project (iPhone, iPad, Mac)
csum/                    app sources
plans/                   project plans
Tests/                   controller tests, and e2e.sh for the CLI
```

## Code review

Every pull request gets an automated first pass from Claude Code through
`.github/workflows/claude-review.yml`. It runs on `ubuntu-latest`, reads the diff
and the surrounding sources, and posts one summary comment plus inline comments
for line-specific findings. It never builds or runs tests: it reviews logic,
the `.csum.csv` format, the layering, and the conventions in `AGENTS.md`, not
compile errors.

The review is skipped for draft pull requests, for pull requests from forks, and
when no credential is configured. To turn it on, add one repository secret under
Settings → Secrets and variables → Actions:

- `ANTHROPIC_API_KEY` — an Anthropic API key, or
- `CLAUDE_CODE_OAUTH_TOKEN` — the token from `claude setup-token`, for Pro and Max
  accounts.

It comments as `github-actions[bot]` using the workflow's own token, so the
Claude GitHub App is not needed. Runs are grouped per pull request, so a new
push cancels a review of the previous commit.
