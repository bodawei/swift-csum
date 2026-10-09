# swift-csum

Compute file checksums (SHA-256, SHA-1, or MD5) with a SwiftUI app on iPhone, iPad, and
Mac, or from the command line. Both front-ends share one hashing implementation
(`Sources/ChecksumCore`), which streams files in 1 MB chunks.

## App

Open `csum.xcodeproj` in Xcode and run the `csum` scheme. Selecting the "Mac"
destination runs the same app on your Mac — no separate macOS target needed.

Tap "Choose File…", pick a file, and the app shows:

- File name
- Full path to the file
- File size
- Creation and modification dates
- Algorithm
- The checksum, with a Copy button

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

```
swift build          # builds the CLI and the shared ChecksumCore library
```

Or build the app from the command line:

```
xcodebuild -project csum.xcodeproj -scheme csum \
    -destination 'generic/platform=iOS Simulator' build
```

## Layout

```
Sources/ChecksumCore/    shared hashing library (CryptoKit)
Sources/csum-cli/        command-line tool (swift-argument-parser)
csum.xcodeproj/          SwiftUI app project (iPhone, iPad, Mac)
csum/                    app sources
plans/                   project plans
```
