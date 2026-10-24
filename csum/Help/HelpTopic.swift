import SwiftUI

struct HelpTopic: Identifiable {
    let id: String
    let title: LocalizedStringKey
    let paragraphs: [LocalizedStringKey]

    static let all: [HelpTopic] = [
        HelpTopic(
            id: "overview",
            title: "What csum Does",
            paragraphs: [
                "csum computes SHA-256 checksums for one file or for every file in a folder, and compares two sets of checksums to show what changed. Everything runs on this device: nothing is uploaded, and no network connection is needed.",
                "A checksum is a fingerprint of a file's contents. Two files with the same checksum have the same contents. If the fingerprint changes, the contents changed — even if the file's name and size did not.",
            ]
        ),
        HelpTopic(
            id: "file",
            title: "File",
            paragraphs: [
                "Use File when you want the checksum of a single file, to check a download or to record what you sent to someone.",
                "1. Open the File tab.",
                "2. Tap Checksum File… and choose a file.",
                "3. The result shows the checksum, the algorithm, the size, the created and modified dates, and the full path.",
                "Copy Checksum copies just the digest. Share — or File > Save As… (⇧⌘S) on the Mac — saves the result as a .csum.csv file.",
            ]
        ),
        HelpTopic(
            id: "folder",
            title: "Folder",
            paragraphs: [
                "Use Folder to checksum everything inside a folder, at every depth, hidden files included.",
                "1. Open the Folder tab.",
                "2. Tap Checksum Folder… and choose a folder.",
                "3. A progress bar shows how far the run has got. Afterwards every file is listed, sorted by its path relative to the folder.",
                "A file that cannot be read is recorded as !cannotOpen or !readFailed and the run carries on, so one unreadable file does not cost you the rest of the results.",
                "The rows hold paths relative to the folder, and the folder itself is recorded once in the file's metadata. That is why a checksum file taken before the tree was moved still compares as unchanged afterwards.",
            ]
        ),
        HelpTopic(
            id: "view",
            title: "View",
            paragraphs: [
                "Use View to read a checksum file back without checksumming anything again.",
                "1. Open the View tab.",
                "2. Tap Open csum file… and choose a .csum.csv or a .csum-compare.csv.",
                "For a .csum.csv the page shows when it was computed, the algorithm, the root the paths are relative to, and every row. For a .csum-compare.csv it shows the rows exactly as the file has them, with the # comment lines in the first column.",
                "This is the way to inspect a results file someone sent you, or one you kept from a folder that is no longer at hand.",
            ]
        ),
        HelpTopic(
            id: "compare",
            title: "Compare",
            paragraphs: [
                "Use Compare to see what changed between two folders, two saved checksum files, or one of each.",
                "1. Open the Compare tab.",
                "2. For each side, choose the source type — a saved .csum.csv, or a folder to checksum on the spot.",
                "3. Tap Choose… and pick the file or folder.",
                "4. Tap Compare. Every entry is grouped into Added, Removed, Changed, Moved, Renamed and Unchanged. Changed, Moved and Renamed show both sides — old and new path, size and times — with the part that differs highlighted.",
                "Swap exchanges the two sides, which flips Added and Removed.",
                "Because entries are matched on their path relative to each root, a folder that has moved since its checksums were taken compares as unchanged, not as all-moved.",
            ]
        ),
        HelpTopic(
            id: "results",
            title: "Results",
            paragraphs: [
                "Every result page offers Share, Copy Results, and — on the Mac — File > Save As… (⇧⌘S). Long-press a row to copy just that row.",
                "Saved files are Excel-ready CSV: RFC 4180 quoting, CRLF line endings, and a UTF-8 BOM, led by # csum-… comment lines recording the format, the tool, when it was computed, the algorithm, and the root the paths are relative to. Checksums are saved as .csum.csv and comparisons as .csum-compare.csv.",
                "Each row is Checksum, Size, Created, Modified, Path. Dates are Unix epoch seconds, empty when a file has no such date. Path is relative to the recorded root, with a leading ./.",
                "A checksum cell holding !cannotOpen or !readFailed means the file could not be read, and is not a digest.",
            ]
        ),
    ]
}
