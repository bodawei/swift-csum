# swift-csum

Compute file checksums with a SwiftUI app on iPhone, iPad, and Mac, or from the command
line (SHA-256 in the app; SHA-256, SHA-1, or MD5 from the CLI). Both front-ends are
thin: the filesystem walk, the checksumming, the diff, and the `.csum.csv` reader and
writer all live in one controller layer (`Sources/CsumController`), which streams files
in 1 MB chunks.

## App

Open `csum.xcodeproj` in Xcode and run the `csum` scheme. Selecting the "Mac"
destination runs the same app on your Mac — no separate macOS target needed.

The app has four tabs:

- **File** — **Checksum File…** picks one file and shows its checksum, algorithm, size,
  created and modified dates, and path. **Copy Checksum** copies the digest (a feature
  flag, on by default).
- **Folder** — **Checksum Folder…** picks a folder and checksums it recursively: every
  file at every depth (hidden files included), with a progress bar while it runs and a
  list or table of results afterwards, sorted by path relative to the folder. A file
  that cannot be read gets a failure code in its checksum cell instead of a digest, and
  the run carries on.
- **View** — **Open csum file…** reads a saved checksum file or a saved comparison back.
  A `.csum.csv` shows the metadata it carries (when it was computed, the algorithm, and
  the root the paths are relative to) with every row in a list or table. A
  `.csum-compare.csv` shows the file's rows as they are, its `#` comment lines included
  in the first column. Nothing is checksummed again (a feature flag, on by default).
- **Compare** — two sources, each a saved `.csum.csv` or a folder, then **Compare**.

Every screen has a **Help** button — the four pickers included — and the Mac menu bar
has **Help > csum Help** (⌘?). Help explains what the app is for, what each tab does
step by step, and how to read a result, one topic per tab.

Every result screen has a **Share** button that exports an Excel-ready CSV file — RFC
4180 quoting, CRLF line endings, UTF-8 BOM — led by five `# csum-…` comment lines
carrying the format version, the tool, the ISO-8601 date, the algorithm, and the root
the paths are relative to. On the Mac, **File > Save As…** (⇧⌘S) writes the same text
through a save panel. **Edit > Copy** (⌘C) on the Mac puts that text on the clipboard
whenever no text is selected, so a result page can be copied without opening the share
sheet. Long-press any row (or right-click it on the Mac) to copy that row as a CSV line.

Checksums are saved as `.csum.csv`, a type this app owns
(`com.djb.csum.csum-csv`). Comparison results are saved as `.csum-compare.csv`, a
separate owned type (`com.djb.csum.csum-compare-csv`), so the two never get mixed up in
a folder. The files are named `<file or folder name>.csum.csv`, or
`Comparison.csum-compare.csv` for a compare; a viewed file keeps its own name. The
checksum row format is:

| Checksum | Size | Created | Modified | Path |
|----------|------|---------|----------|------|

- `Checksum` — lowercase hex digest, or `!cannotOpen` / `!readFailed` if the file could
  not be read.
- `Size` — size in bytes.
- `Created` / `Modified` — creation and modification dates as Unix epoch seconds
  (long integers); empty if the file has no such date.
- `Path` — the file's path relative to the root, written with a leading `./`
  (`./notes.txt`, `./sub/b.txt`). It is last because it is the only field whose width
  varies wildly: a table of rows is far easier to read with the path out of the way.

Paths are relative, and the root they are relative to is recorded once in the metadata:
the folder that was checksummed, or the folder holding a single file. A row plus the
root is the file's absolute path, and a checksum file taken before the tree was moved
still compares as unchanged afterwards.

### Comparing

Each source has a dropdown choosing **.csum.csv** (a saved checksum file) or **Folder**
(checksummed on the spot). **Swap** exchanges the two; **Compare** enables once both are
chosen and groups every entry into color-labeled sections: **Added**, **Removed**,
**Changed**, **Moved**, **Renamed**, and **Unchanged** — with old and new path, size,
and times side by side for Changed, Moved, and Renamed. Narrow windows show collapsible
groups with counts; wide ones show the same thing as a table. An identical pair says
"No differences" instead.

Notes:

- To run on a real device or distribute the Mac build, set a Development Team under
  Signing & Capabilities. Simulator builds need no signing.
- The bundle identifier `com.djb.csum` is a placeholder — change it in the target's
  Signing & Capabilities settings.
- The app computes SHA-256; use the command line for SHA-1 or MD5.

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

A single file is recorded against the folder that holds it: `csum-cli check ~/a.txt`
writes `# csum-root /Users/you` and one row whose path is `./a.txt`.

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
swift test         # the controller: checksumming, the diff, the readers and writers
bash Tests/e2e.sh  # the CLI against shasum, on a temporary tree
```

The app's unit tests (`csumTests`) and UI flow tests (`csumUITests`) run from the `csum`
scheme in Xcode, or with `xcodebuild test` against a Mac Catalyst destination.

## Pull request review

Pull requests from a branch in this repository get a review from
`anthropics/claude-code-action` (`.github/workflows/claude-review.yml`). The job needs
either `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` as a repository secret
(**Settings → Secrets and variables → Actions**), and fails with that instruction
instead of passing silently when neither is set.

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
csum/                    app sources: App, FeatureFlags/, Sections/, Shared/, Demo/
csumTests/               app unit tests
csumUITests/             app UI flow tests
plans/                   project plans
Tests/                   controller tests, and e2e.sh for the CLI
```

## Telemetry

The controller is instrumented with [OpenTelemetry](https://opentelemetry.io): every
`calculateChecksums(at:)` call and every `compare(first:second:)` call records a span,
through `opentelemetry-swift-core`. A `csum.compare` span nests the
`csum.calculateChecksums` spans it triggers when a side is checksummed live.

| Span | Attributes |
|------|------------|
| `csum.calculateChecksums` | `csum.algorithm`, `csum.path`, `csum.entry_count` |
| `csum.compare` | `csum.first.path`, `csum.second.path`, `csum.algorithm`, and the `csum.unchanged.count`, `csum.changed.count`, `csum.added.count`, `csum.removed.count`, `csum.moved.count`, `csum.renamed.count` counts |

A thrown error is recorded as an exception event and sets the span status to error. The
controller depends only on `OpenTelemetryApi`, so the spans are no-ops until the process
registers a `TracerProvider`.

The app does that in `csum/Telemetry.swift`, exporting over OTLP/HTTP to [PostHog's OTLP
endpoint](https://posthog.com/docs/opentelemetry). Two things have to be configured,
either in the environment or as string keys in `Info.plist`:

- `POSTHOG_PROJECT_TOKEN` — the same `phc_…` token the flags use. Traces go to
  `/i/v1/traces` on `POSTHOG_HOST` (default `https://us.i.posthog.com`) with that token as
  a bearer token, and show up under **Tracing** in PostHog.
- `OTEL_EXPORTER_OTLP_ENDPOINT` — an alternative destination, for a local collector. It
  wins over the PostHog settings and is sent without an authorization header. An endpoint
  with no path gets `/v1/traces` appended, so both of these work:

```
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318/v1/traces
```

With neither configured the app keeps the no-op provider and sends nothing. The CLI
registers no provider either, so `csum-cli` exports nothing.

The app can also record its own spans, through `Logger.startSpan(name:attributes:)` and
`Logger.endSpan(_:)`. They go to whichever provider is registered, so they land beside the
controller's spans in PostHog. Both do nothing until `Logger.start()` has started PostHog
with a project token:

```swift
let span = Logger.shared.startSpan(name: "export_results", attributes: ["entry_count": .int(3)])
defer { Logger.shared.endSpan(span) }
```

## Feature flags

Feature flags come from [PostHog](https://posthog.com) through its iOS SDK. Each flag is
declared, with its default, in `Sources/CsumController/Model/FeatureFlag.swift`;
`csum/FeatureFlags/PostHogFeatureFlags.swift` evaluates it in PostHog, and
`FeatureFlagStore` publishes the values to the views.

| Flag | Default | Gates |
|------|---------|-------|
| `csum.copy-checksum` | on | The **Copy Checksum** button on the File result |
| `view_tab` | on | The **View** tab, which reads a saved `.csum.csv` |

To connect a PostHog project, set the project token (the `phc_…` key) as
`POSTHOG_PROJECT_TOKEN`, either in the scheme's environment or as a string key in
`Info.plist`, and create a boolean flag whose key is the flag's raw value and which
returns `true` for everyone you want to see the feature. `POSTHOG_HOST` picks the
ingestion host and defaults to `https://us.i.posthog.com`; set it to the EU host if the
project lives there. Turning a flag on or off in PostHog changes the app without a new
build: the store refreshes when the SDK reports that the flags have loaded.

With no token configured the app never contacts PostHog and every flag keeps its default,
so a checkout builds and runs offline. When a token is set, PostHog identifies the device
with the anonymous distinct ID its SDK generates and keeps, so a flag rollout can be
narrowed or widened for a particular install.
