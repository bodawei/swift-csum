# Plan 3: report the result as a spreadsheet-like table

## Goal
Replace the GUI result card's vertical list of labeled rows with a table that has
column headings and visible cell boundaries, so the fields don't run together. The
table has one header row and one data row, with exactly these columns, in this order:

```
Filename | Checksum | Algorithm | Size | Created | Modified | Path
```

## Format decisions
- `Checksum` — lowercase hex digest, monospaced.
- `Algorithm` — machine-friendly raw value (`sha256` / `sha1` / `md5`), matching the CLI.
- `Size` — raw byte count (integer), not a human-formatted string.
- `Created` / `Modified` — Unix epoch seconds as long integers; empty cell if the file
  has no such date.
- `Path` — the file's full path, monospaced.
- Layout: SwiftUI `Grid` + `GridRow` (iOS 16 / macOS 13 — the deployment floor), each
  cell padded and outlined so cell boundaries are visible; the whole table scrolls
  horizontally when values (checksum, path) are wider than the window. Single-line
  cells, leading-aligned columns.
- Copy Row button copies the data row as a tab-separated line with the same seven
  fields in the same order (paste-ready for a spreadsheet).

## Files touched
- `csum/ContentView.swift` — `resultCard` renders the headed, bordered `Grid`;
  `tsvLine(for:)` extended with the path as the 7th field; `labeledRow` helper
  removed.
- `README.md` — App section updated.
- The CLI is unchanged (stdout stays exactly the digest).

## Verification
- Typecheck `csum/ContentView.swift` against the macOS SDK.
- `xcodebuild` for iOS Simulator and Mac Catalyst — both `BUILD SUCCEEDED`.
