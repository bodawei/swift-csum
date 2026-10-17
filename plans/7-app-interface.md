# Plan 7: the app interface

## Goal

A new interface for the app: one window, three independent sections reached from a three
item toolbar at the bottom of the screen. The first section checksums a file, the second
checksums a folder, the third compares two sources. Each section keeps its own state and
its own results, and each can run while another is running.

The base surface is the system background — white in light mode, black in dark mode — and
every control is a standard SwiftUI component, so the interface inherits the system look,
the system motion, and the system accessibility behaviour without custom drawing.

Mockups for everything described here are in [`images/gui`](images/gui) and embedded
below.

## Shape

```
RootView
  TabView(selection: app.selectedSection)
    FileSectionView      NavigationStack(path: file.path)
      picker page        "Checksum File…"
      result page        metadata, key/value pairs, share
    FolderSectionView    NavigationStack(path: folder.path)
      picker page        "Checksum Folder…"
      result page        progress, then table, share
    CompareSectionView   NavigationStack(path: compare.path)
      picker page        two sources, Compare
      result page        spinner, then tree of diff sections, share
```

The bottom toolbar is a `TabView` with three `Tab`s (File, Folder, Compare). It is the
standard component, so it is the floating, translucent, Liquid Glass bar on the current
system and the plain tab bar on older ones. No custom bar is drawn.

Each section is a `NavigationStack` whose path lives in that section's model. Picking a
source appends `.result` to the path, which gives the slide-in from the right for free,
and the back button in the result toolbar pops it. Switching tabs does not destroy a
section: the three stacks, their tasks and their results live in `AppModel` for the
lifetime of the window.

## Layers

Per `AGENTS.md`, the split is:

| Layer | Where | Owns |
|-------|-------|------|
| View | `csum/App`, `csum/Sections/*/*View.swift`, `csum/Shared` | Layout, animation, presentation modifiers, local expansion and scroll state, accessibility identifiers and labels |
| ViewModel | `csum/App/AppModel.swift`, `csum/Sections/*/*Model.swift` | Selected tab, per-section navigation path, source selection, load/result/error state, tasks, progress, export text, delayed-spinner flag |
| Controller | `Sources/CsumController` | Filesystem access, checksumming, diffing, `.csum.csv` reading and writing |
| Access / remote | none | — |

The models import Foundation and Observation only; no SwiftUI. The views contain no
file I/O, no checksumming, no formatting logic beyond calling the shared formatters.

### What each model owns

`AppModel`:

```swift
@MainActor @Observable
final class AppModel {
    enum Section: Hashable { case file, folder, compare }
    var selectedSection: Section = .file
    let file: FileSectionModel
    let folder: FolderSectionModel
    let compare: CompareSectionModel
}
```

`FileSectionModel` / `FolderSectionModel`:

```swift
enum Phase {
    case idle
    case running
    case loaded(ChecksumResult)
    case failed(message: String)
}

var phase: Phase
var path: [Route]                  // [] or [.result]
var isChoosingSource: Bool         // drives .fileImporter
var progress: (done: Int, total: Int)?
var showsDelayedSpinner: Bool      // file section only
var export: CsumCSVFile?           // non-nil only when loaded
```

`CompareSectionModel` adds `first: URL?`, `second: URL?`, `isChoosingFirst`,
`isChoosingSecond`, and a `Phase` whose loaded case carries `ChecksumComparison`.

Everything derived is computed from the model: section results are never shared between
sections, and an error in one section leaves the other two untouched.

### Views

| View | Responsibility |
|------|----------------|
| `RootView` | `TabView` with the three sections and the tab labels/icons |
| `*SectionView` | The picker page: the centered button or the two source cards; the `.fileImporter` modifiers bound to the model's flags |
| `*ResultView` | Switches on `model.phase`: progress/spinner, results, or error; hosts the result toolbar |
| `MetadataStrip` | Small secondary text above the results: root(s), computed time, format version |
| `ResultToolbar` | Back (leading, system) and `ShareLink` (trailing, disabled unless loaded) |
| `ErrorStateView` | Icon, localized message, nothing else; back stays, share is disabled |
| `DiffSectionView` / `DiffRowView` | Collapsible sections and the diff rows |

## The three sections

### File

Idle page: a single centered "Checksum File…" button on the system background. Tapping it
sets `isChoosingSource`, which presents `.fileImporter(allowedContentTypes: [.data])`.
Choosing a file:

1. appends `.result` to the path, so the result page slides in immediately;
2. starts the checksum task on the service;
3. arms a 500 ms timer. If the task is still running when it fires, `showsDelayedSpinner`
   becomes true. If the task finished first, the spinner never appears and the result is
   simply there.

Result page, top to bottom: the back/share toolbar; the metadata strip (absolute path,
computed date, format version); then either the spinner, the error, or the key/value
pairs: checksum (monospaced), algorithm, size, created, modified, path. Dates are
locale-formatted, not epoch numbers.

Share is enabled only in the loaded state and shares the rendered `.csum.csv` text.

![File section, idle](images/gui/01-file-start.svg)

![File section, result](images/gui/02-file-result.svg)

### Folder

Idle page: "Checksum Folder…" presents `.fileImporter(allowedContentTypes: [.folder])`.
Choosing a folder pushes the result page and starts the task. The result page shows a
determinate progress bar (`ProgressView(value:total:)`) with a label such as
"12,345 of 48,201 files", updated at most ten times a second, until the result arrives.

Then the results page shows the metadata strip — root, computed time, format version,
algorithm, entry count — and a table with these columns:

| Column | Content | Alignment |
|--------|---------|-----------|
| Name | path relative to the root | leading |
| Size | `ByteCountFormatStyle` (3.8 MB, 812 KB) | trailing |
| Modified | locale date | trailing |
| Checksum | monospaced, middle-truncated, full value via VoiceOver and copy | trailing |

The table is `Table`, which is virtualized on every platform. Rows are keyed by
`ChecksumEntry.path`. Thousands or hundreds of thousands of rows scroll without
materializing extra arrays. Selection is enabled so a row can be copied.

On compact widths the checksum column truncates hard; if that proves unreadable in
practice, the fallback is a two-line `List` row (name, then size and date, checksum in a
detail sheet) — one view swap, no model change.

![Folder section, running](images/gui/03-folder-progress.svg)

![Folder section, results](images/gui/04-folder-result.svg)

### Compare

The picker page has two source cards. Each card has File… and Folder… buttons; both
accept `.csum.csv` files as well as ordinary files, since the controller treats a saved
checksum file as just another source. A source is shown with its kind once chosen. A swap
control exchanges the two. Compare is enabled only when both are set; it pushes the result
page and starts the comparison, which has no progress reporting, so the result page shows
an indeterminate spinner.

The result page shows the metadata strip with **both** roots, both computed times and the
format version, then the counts, then a `List` of collapsible sections in this order:
Added, Removed, Changed, Moved, Renamed, Unchanged. Each section header carries its count.
Added, Removed and Changed start expanded; the rest start collapsed; expansion is view
state and resets with each new comparison. A comparison with no differences shows a
"No differences" state instead of an empty list.

Share is enabled only when loaded, and exports `ComparisonFileCodec.render(comparison,
sections: ComparisonSection.allCases)`.

![Compare section, picker](images/gui/05-compare-picker.svg)

![Compare section, results](images/gui/06-compare-results.svg)

## Diff rows

Every row is one line of text plus a leading symbol, so the meaning survives without
colour and without sight. Added rows are green with `+`; removed rows are red with `−`;
unchanged rows are ordinary text. Changed, moved and renamed produce a pair: the old row
first, then the new row.

| Section | Symbol | Emphasis | Accessibility label |
|---------|--------|----------|---------------------|
| Added | `+`, green | none | "Added, path" |
| Removed | `−`, red | none | "Removed, path" |
| Unchanged | none | none | "Unchanged, path" |
| Changed | `−` / `+` | the checksum in both rows | "Changed, path, old checksum …, new checksum …" |
| Moved | `−` / `+` | the whole path in both rows | "Moved from …, to …" |
| Renamed | `−` / `+` | the leaf name in both rows | "Renamed from …, to …" |

Emphasis is an `AttributedString` background on the affected span, in colour assets with
light, dark and increased-contrast variants. The diff rows are the only place that needs
custom accessibility labels; everything else gets them from the standard components.

![Diff rows, detail](images/gui/07-diff-detail.svg)

## Services

The controller is synchronous and CPU-bound, so the models talk to it through one
async boundary:

```swift
protocol Checksumming: Sendable {
    func checksum(
        at url: URL,
        progress: @Sendable (Int, Int) -> Void
    ) async throws -> ChecksumResult

    func compare(first: URL, second: URL) async throws -> ChecksumComparison
}
```

`ControllerService` wraps `CsumController`, runs each call on a detached user-initiated
task, and hops progress back to the main actor. The models throttle progress to ten
updates a second before publishing it. The protocol is what the unit tests fake; nothing
in the models refers to `CsumController` directly.

Two small controller additions are needed:

- `calculateChecksums` takes an optional `isCancelled: @Sendable () -> Bool`, checked per
  file, so leaving the section cancels promptly instead of hashing the rest of a tree.
  `compare` passes the same hook to both sides.
- a public `relativePath(of:root:)` helper (today the equivalent is private inside the
  comparison engine), so the folder table can show paths relative to the root.

Both are additive and covered by controller tests.

## Sharing

`CsumCSVFile` is a `Transferable` that writes its text to a temporary file with the given
name and declares `FileRepresentation(exportedContentType: .commaSeparatedText)`, so the
share sheet offers the right destinations for a CSV. The file section and the folder
section export `ChecksumFileCodec.render(result)`; the compare section exports
`ComparisonFileCodec.render(comparison)`.

`ShareLink(item: export, preview: SharePreview(fileName))` sits in the result toolbar and
is disabled (not hidden) unless the section is loaded, so it never disappears between
states.

## Formatting and localization

- One `Localizable.xcstrings` in the app target; every user-visible string is a `Text`
  literal or `String(localized:)`, including accessibility labels and the share filename
  (`Checksums for %@.csum.csv`).
- Counts use plural variants: "%lld file", "%lld files".
- Dates use `Date.FormatStyle` (`Text(date, format: .dateTime…)`); no hand-built strings
  and no epoch numbers in the UI.
- Sizes use `ByteCountFormatStyle`; counts use the default number format. Neither is
  concatenated with a hard-coded unit.
- Columns use `.leading`/`.trailing` rather than left/right, so the system mirrors them in
  right-to-left locales. Table cell text is `.multilineTextAlignment` on the same leading
  and trailing edges.
- Paths and checksums are rendered with `Text(verbatim:)` so they are not parsed as
  numbers or dates, and they get `.textSelection(.enabled)` where they are not in a table.
- The share filename is built from the localized template, not by string concatenation.

## Accessibility

Everything visible is a stock control, so labels, traits, focus order and rotor support
come for free: tabs, nav bars, buttons, the progress bar, the table and the share sheet.
On top of that:

- Diff rows combine their children and carry the labels in the table above; the symbol is
  hidden from VoiceOver because it is already in the label.
- The progress bar has a label ("Checksumming Folder…") and a value ("12,345 of 48,201
  files"); the delayed spinner has a label ("Checksumming…") and posts a live region
  announcement when it appears.
- The metadata strip is a set of `LabeledContent`s, so VoiceOver reads "Root, …", not a
  run-on line.
- Colour is never the only signal (symbol plus label), and the diff tints are tested in
  Increase Contrast and dark mode.
- Everything uses text styles and `@ScaledMetric` for icon and row padding, so Dynamic
  Type up to AX5 does not clip the toolbar, the metadata strip or the diff rows.
- UI tests run `performAccessibilityAudit()` on the idle, running, loaded and failed
  states of all three sections.

No other custom accessibility information is needed. The diff rows and the two live
announcements are the whole list.

## Errors

A failure in any section replaces that section's results with `ErrorStateView`: the
localized error message (the controller already conforms to `LocalizedError`), the back
button, and a disabled share. The tab bar stays usable; the other sections keep their
state and results. A cancelled task returns the section to idle rather than showing an
error.

## Large data

- The folder table is `Table`, the compare results are `List` with collapsed sections;
  both are virtualized. Only visible rows render.
- No section copies its result into a second array. The folder table iterates
  `result.entries`; the compare list iterates the comparison's arrays; the diff emphasis
  is computed per visible row.
- Rows are keyed by `entry.path` (already `Hashable`), so updates reuse rows.
- Progress is throttled in the model; the controller's callback is not forwarded to the
  main actor on every file.
- Target: a 100,000 entry folder result scrolls at full frame rate on an iPhone 16-class
  device, and the compare screen opens with 100,000 unchanged rows collapsed in under a
  second. Both are exercised in stub mode with a generated result.

## Choosing a source

All sources come from `.fileImporter` (single selection; `.data` for files, `.folder` for
folders, both for the compare cards), which returns security-scoped URLs. The controller
already brackets each call with `startAccessingSecurityScopedResource`, so the models keep
the URL as the source and the security scope remains local to the controller call.

## Testing

### Controller

`swift test` covers checksumming, the diff, the formats and the new cancellation hook.
The existing suite also gains a test that a cancelled run stops before hashing the rest
of the tree and throws `CancellationError`.

### View models

A `FakeChecksumService` with continuations and a `TestClock` drive the section models
directly, with no SwiftUI and no file system:

- picking a source pushes the result route and enters `.running` before the task finishes;
- the file spinner is false at 499 ms and true at 501 ms if the task is still running, and
  never appears if the task completes first;
- a successful run yields `.loaded` with a non-nil export; a failed run yields `.failed`,
  a nil export, and the message;
- cancel on back returns to `.idle` and cancels the service task;
- compare is only startable with both sources;
- the three models are independent: running, failing or loading one does not change the
  other two, and switching tabs does not cancel a task.

### Views and flows

XCUITest targets, run against a stub service selected by a launch argument
(`-csumUITestMode stub`), so the tests do not depend on real files:

- file: idle → pick → result, spinner appears only for the slow stub;
- folder: progress label updates, then the table appears; 200 rows scroll;
- compare: two picks enable Compare, results show the counts, sections expand and
  collapse, the diff rows expose their labels;
- error: a failing stub shows the message, share stays disabled, back works;
- localization: the same three flows under the double-length pseudolocale;
- accessibility: `performAccessibilityAudit()` on every state;
- performance: signpost-style measure of scrolling a 100,000 row stub result.

Snapshot tests are optional and not part of the plan: the UI is built from standard
components whose rendering changes with the OS, so a snapshot suite would spend its life
being re-recorded. The accessibility audits and the flow tests are the durable check.

### Manual pass

Light and dark, iPhone and iPad, Mac Catalyst, Dynamic Type AX1 and AX5, Increase
Contrast, right-to-left (Arabic) and a pseudo-locale, VoiceOver through each section, and
the three share sheets.

## Coverage

The controller and the models are the units worth measuring; the views are exercised by
the UI tests rather than by line coverage.

Controller (SwiftPM, macOS):

```sh
swift test --enable-code-coverage

xcrun llvm-cov report \
  .build/debug/CsumControllerTests.xctest/Contents/MacOS/CsumControllerTests \
  -instr-profile .build/debug/codecov/default.profdata \
  -ignore-filename-regex 'Tests/|\.build/'
```

That currently reports 91.60% of lines, 93.01% of functions and 94.96% of regions across
the controller. Per-file numbers come from the same command, and
`xcrun llvm-cov show … --show-line-counts-or-regions` shows the unexecuted lines. For a
CI artifact, `xcrun llvm-cov export -format=lcov` writes the same data as LCOV;
`swift test --enable-code-coverage --show-codecov-path` prints the profile path.

App and view models (Xcode, Mac Catalyst destination — no simulator needed):

```sh
xcodebuild test \
  -project csum.xcodeproj -scheme csum \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  -enableCodeCoverage YES -resultBundlePath build/coverage.xcresult

xcrun xccov view --report build/coverage.xcresult
xcrun xccov view --report --json build/coverage.xcresult > build/coverage.json
```

`-only-testing:csumTests` limits the run to the model tests. The UI tests run on an iOS
simulator destination for the accessibility audit, with the same coverage flags if their
coverage matters.

Targets: 90% of lines in the section models and the service adapter; 100% of the state
transitions listed under "View models". Coverage of SwiftUI view bodies is not a goal and
is excluded with `-ignore-filename-regex`.

The package and the app are Apple-only (`CryptoKit`, SwiftUI), so none of this runs on the
Linux CI workflows; coverage needs a macOS runner, or a developer machine.

## Work order

1. **Target reset.** Remove the current app sources and their target membership, point the
   app target at the `CsumController` package product, set the deployment targets, add the
   string catalog and the diff colour assets. The target builds and launches empty.
2. **Plumbing.** `Checksumming` + `ControllerService`, the controller cancellation hook
   and relative-path helper, `CsumCSVFile`, the shared formatters. Controller tests green.
3. **Shell.** `AppModel`, `RootView`, the three tabs, empty section pages.
4. **File section.** Picker, route, delayed spinner, key/value result, error, share.
5. **Folder section.** Progress, table, metadata, error, share.
6. **Compare section.** Two sources, swap, spinner, collapsible sections, diff rows,
   error, share.
7. **Localization and accessibility.** String catalog complete, audits clean, pseudo-locale
   pass.
8. **Tests and coverage.** Model tests, UI tests, coverage commands wired up.
9. **Performance pass.** 100,000 row stub, scroll and open timings recorded.

## Decisions to confirm

- **iOS 18 / macOS 15 deployment floor** (needed for `@Observable`; Liquid Glass itself
  needs no floor because it comes from the SDK). Keeping iOS 16 means `ObservableObject`
  and a slightly noisier diffing story, but nothing else changes.
- **Checksum column on the phone table**: truncate it there (current plan) or move it to a
  row detail.
- **Compare sources**: any two of file, folder, `.csum.csv` (current plan, matching the
  controller) rather than restricting each side to one kind.
- **Drag and drop** into the picker pages is not in this plan; it is additive later
  (`dropDestination(for: URL.self)`) and changes nothing in the models.
- **Which locales** to seed beyond English and the pseudo-locale.
