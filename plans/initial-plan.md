# Plan: swift-csum — iOS/iPadOS/Mac (Catalyst) app + macOS CLI

## Goal
1. A SwiftUI app that lets the user pick a file, computes its checksum with CryptoKit,
   and displays: file name, full file path, and the checksum. Single codebase runs on
   iPhone, iPad, and Mac via **Mac Catalyst** (Xcode's "Mac" destination — the "run iPad
   app on Mac" mechanism the user referred to).
2. A command-line tool, using Apple's **swift-argument-parser** (the standard package
   for Swift CLI argument parsing), that takes a full pathname and echoes the checksum
   to stdout.

Both front-ends share one hashing implementation in an SPM package inside this repo.

## Pre-code steps (before any Swift/codegen)
1. Create `plans/initial-plan.md` in the repo containing this plan, per user request.
2. Create `AGENTS.md` in the repo root with the instruction: `Do not add comments to
   any file`. All subsequently generated code must be comment-free.

## Environment facts (already checked)
- Repo is empty except `README.md` (title only) and a stock Xcode `.gitignore`.
- Xcode 27.0, Swift 6.4 installed. No `xcodegen`/`tuist` — project files authored by
  hand and verified with `xcodebuild`/`swift build` (no new tooling installed).

## Repo layout
```
Package.swift                     SPM package
Sources/
  ChecksumCore/                   library target — shared hashing code
    ChecksumAlgorithm.swift       enum sha256 / sha1 / md5 (CryptoKit SHA256,
                                  Insecure.SHA1, Insecure.MD5) + display names
    ChecksumCalculator.swift      non-isolated; streams the file in 1 MB chunks
                                  (no whole-file memory load); returns lowercase hex
  SwiftCSUM/                      executable target
    main.swift                    ArgumentParser entry point
swift-csum.xcodeproj/             iOS app project (depends on local package product
                                  ChecksumCore; no third-party code in the app target)
swift-csum/                       app sources only (ChecksumApp.swift, ContentView.swift)
    Assets.xcassets/              minimal catalog: empty AppIcon + AccentColor
README.md                         usage for both app and CLI
```

## CLI design (`swift-argument-parser`)
- Package dependency: `https://github.com/apple/swift-argument-parser` from `1.5.0`.
- Executable product named `swift-csum` (target `SwiftCSUM`).
- Interface:
  - Positional `<path>`: full pathname of the file (required).
  - `--algorithm <sha256|sha1|md5>` (`-a` shorthand), default `sha256`.
  - `ChecksumAlgorithm` gains `ExpressibleByArgument` conformance **in the CLI target**
    so `ChecksumCore` itself has no ArgumentParser dependency.
- Output: just the lowercase hex digest + newline on stdout (nothing else — matches
  "echo the checksum"; like `shasum` without the filename column).
- Errors: unreadable/missing file → clear message on stderr, non-zero exit
  (via thrown `ValidationError`/`LocalizedError`).

## App design (SwiftUI)
- `ChecksumApp.swift` — `@main` entry.
- `ContentView.swift`:
  - Segmented algorithm picker (SHA-256 default / SHA-1 / MD5).
  - "Choose File…" via `.fileImporter(isPresented: types: [.data])` — UIDocumentPicker
    on iOS/iPad, NSOpenPanel on Catalyst; one API for all three platforms.
  - On pick: `startAccessingSecurityScopedResource()` …
    `stopAccessingSecurityScopedResource()` around the read (required for
    document-picker URLs); hash off-main with `Task.detached`; `ProgressView` while
    working; error alert on failure.
  - Result card showing exactly what was requested — **File name** (bold), **Path**
    (monospaced, selectable), **Size**, **Algorithm**, **Checksum** (monospaced) — plus
    a Copy button and "Choose Another File…". `NavigationStack` layout; works as-is on
    iPhone, iPad, and Catalyst.
- Xcode project settings: deployment iOS 16.0,
  `TARGETED_DEVICE_FAMILY = "1,2"`, `SUPPORTS_MACCATALYST = YES`,
  `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`,
  `GENERATE_INFOPLIST_FILE = YES` (no hand-written Info.plist),
  `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`, bundle id placeholder
  `com.djb.swift-csum` (changeable in Xcode), local package reference to `ChecksumCore`.

## Verification (all before handing back)
- `swift build` — package builds (core + CLI).
- `swift run swift-csum <file>` output == `shasum -a 256 <file>` digest; also spot-check
  `-a sha1` vs `shasum -a 1` and `-a md5` vs `md5`. Missing file → non-zero exit + stderr.
- `xcodebuild -project swift-csum.xcodeproj -scheme swift-csum -destination
  'generic/platform=iOS Simulator' build` (CODE_SIGNING_ALLOWED=NO) — succeeds.
- `xcodebuild -project swift-csum.xcodeproj -scheme swift-csum -destination
  'generic/platform=macOS,variant=Mac Catalyst' build` (CODE_SIGNING_ALLOWED=NO) —
  succeeds. (If `xcodebuild -list` can't auto-discover the scheme, add a shared
  `xcscheme` under `swift-csum.xcodeproj/xcshareddata/xcschemes/`.)

## Notes for the user
- First `swift build`/Xcode open fetches `swift-argument-parser` from GitHub (network
  needed once; pinned to 1.5.x, recorded in `Package.resolved`).
- To run on a real device or distribute the Catalyst Mac build, set a Development Team
  in Xcode (Signing & Capabilities); simulator builds need no signing.
- Bundle id `com.djb.swift-csum` is a placeholder — trivially changed in project settings.
