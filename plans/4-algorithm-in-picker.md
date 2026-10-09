# Plan 4: algorithm selection as part of the file-picking step

## Goal
Move algorithm selection out of the standalone segmented control and make it a
dropdown that is chosen together with picking the file.

## Platform reality
- **iOS / iPadOS / Mac Catalyst**: the system picker (`UIDocumentPickerViewController`,
  surfaced via SwiftUI `.fileImporter`) exposes no API for adding controls inside the
  dialog. An in-dialog dropdown is impossible there.
- **Native macOS** (the "My Mac" destination, macOS SDK build): we present
  `NSOpenPanel` directly and set its `accessoryView` — a real dropdown **inside the
  open dialog**, exactly as requested.

## Design
- **macOS**: "Choose File…" presents an `NSOpenPanel` with an accessory view
  (label + `NSPopUpButton` listing SHA-256 / SHA-1 / MD5). The popup's selection is
  applied to the picked file's checksum after the panel closes, and is persisted.
- **iOS / iPad**: a menu-style `Picker` (dropdown look) sits next to the "Choose File…"
  button. The selection persists via `@AppStorage`, so it defaults to the last-used
  algorithm — the picking flow stays one-tap.
- The result table, TSV copy row, and CLI are unchanged.

## Files touched
- `csum/ContentView.swift` — macOS `NSOpenPanel` path with accessory view; iOS dropdown
  picker bound to persisted selection; `.fileImporter` kept for iOS only.
- `README.md` — App section updated.

## Verification
- Typecheck `csum/ContentView.swift` against the macOS SDK (exercises the
  `NSOpenPanel` accessory code).
- `xcodebuild` for iOS Simulator and Mac Catalyst — both `BUILD SUCCEEDED`.
- Note: the in-dialog accessory view can only be exercised in a real GUI run on the
  "My Mac" destination, not from the CLI.
