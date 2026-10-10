# Plan 5: recursive folder checksums

## Goal
The picker accepts **files and folders, multiple items at once**. Every selected file
is checksummed; every selected folder is checksummed **recursively** — each file found
in it (including files in nested subfolders, at any depth) gets a row in the table.
Files that fail to read get `Error: <details>` in their checksum cell instead of a
digest.

## Decisions (confirmed with the user)
- **Hidden files are included** — dotfiles like `.DS_Store` are checksummed too.
- **Multiple selection is allowed** — several files and/or folders in one dialog; the
  table lists all of them.
- Files are listed **sorted by full path**, so the table is stable and readable.
- Symbolic links are skipped entirely (prevents cycles through linked folders).
- The algorithm chosen in the picker applies to every file in the selection.
- One selected file = a one-row table; an empty folder shows a "no files" message.

## Design
- **Model**: `FileChecksumResult` gains `errorMessage: String?`; the view holds
  `result: [FileChecksumResult]` (rows) instead of a single optional result.
- **Enumeration**: for each picked URL, if it's a directory, `FileManager.enumerator`
  (recursive, `.skipsSymbolicLinks`) collects every non-directory URL; files and
  folder contents are merged and sorted by path.
- **Hashing**: each file is hashed on a background task with the selected algorithm;
  per-file failures are caught and become rows with `errorMessage` set — hashing
  never aborts the batch. Security-scoped access from the picker is held across the
  whole batch for each picked URL.
- **Progress**: files are counted first, then a `ProgressView` shows
  "Computing checksum n of m…" as rows complete.
- **Table**: rows render in a `LazyVStack` (only visible rows materialize — a plain
  `Grid` builds every row eagerly and exhausts memory on folders with tens of
  thousands of files), with fixed column widths shared by header and rows and per-cell
  outlines for the bordered look; scrolled both horizontally and vertically. The Copy
  button copies **all** rows as tab-separated lines (one per file). The progress
  counter updates every 37 files (a prime, so the counts visibly change) rather than
  per file.
- **macOS**: two actions — "Choose Files…" and "Choose Folder…" present an
  `NSOpenPanel` in the matching mode (files-only / folders-only), each with the
  algorithm accessory dropdown.
- **iOS**: the system document picker cannot mix files and folders in one dialog
  (with `[.item]` folders always navigate), so there are two importers — one with
  `[.item]` for files, one with `[.folder]` for folders — both multi-select.
- The CLI is unchanged.

## Files touched
- `csum/ContentView.swift` — batch model, enumeration, per-file error rows,
  scrollable multi-row grid, Copy Rows, progress counter.
- `README.md` — App section updated.

## Verification
- Typecheck against the macOS SDK; `xcodebuild` for iOS Simulator and Mac Catalyst —
  all clean.
- Folder recursion and multi-select are exercised in a GUI run (not possible from the
  CLI): pick a folder on the Mac destination and confirm nested files each get a row.
