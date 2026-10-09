# Plan 2: add creation and modification dates to the GUI result

## Goal
In the app's result card, alongside file name, path, size, algorithm, and checksum,
also report the file's **creation date** and **last modification date**.

## Approach
- Read the dates from the same URL resource-values call the app already makes for file
  size (it runs inside the existing security-scoped access window):
  extend `resourceValues(forKeys:)` with `.creationDateKey` and
  `.contentModificationDateKey`.
- Add `creationDate: Date?` and `modificationDate: Date?` to `FileChecksumResult`
  (both optional — a file can lack either date).
- In `resultCard`, insert a "Created" row and a "Modified" row between Size and
  Algorithm, rendered only when the corresponding date is present, formatted with
  `formatted(date: .abbreviated, time: .shortened)` (iOS 15+/macOS 12+, locale-aware,
  no `DateFormatter` setup).
- The CLI is unchanged (stdout stays exactly the digest, per the original spec).

## Files touched
- `swift-csum/ContentView.swift` — result model, resource-value fetch, two new rows.
- No changes to `ChecksumCore`, the CLI, or project settings.

## Verification
- Typecheck `ContentView.swift` against the macOS SDK (the configuration that
  previously surfaced UIKit errors).
- `xcodebuild` for iOS Simulator and Mac Catalyst — both `BUILD SUCCEEDED`.
