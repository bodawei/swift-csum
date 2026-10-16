import ArgumentParser
import CsumController
import Foundation

extension ChecksumAlgorithm: ExpressibleByArgument {}

struct CsumCLI: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "csum-cli",
            abstract: "Compute checksums, or compare two checksum sources."
        )
    }

    @Argument(help: "One file/directory to checksum, or two sources to compare (.csum.csv files and/or files/directories).")
    var paths: [String]

    @Option(name: [.customShort("c"), .long], help: "The checksum algorithm to use when computing.")
    var algorithm: ChecksumAlgorithm = .sha256

    @Flag(name: .shortAndLong, help: "Include unchanged entries in compare output.")
    var unchanged = false

    @Flag(name: .shortAndLong, help: "Include deleted entries in compare output.")
    var deleted = false

    @Flag(name: .shortAndLong, help: "Include added entries in compare output.")
    var added = false

    @Flag(name: .shortAndLong, help: "Include modified entries in compare output.")
    var modified = false

    @Flag(name: [.customShort("o"), .long], help: "Include moved entries in compare output.")
    var moved = false

    @Flag(name: [.customShort("r"), .long], help: "Include renamed entries in compare output.")
    var renamed = false

    func run() throws {
        guard (1...2).contains(paths.count) else {
            throw ValidationError("Provide one path to checksum, or two to compare.")
        }

        for path in paths where !FileManager.default.fileExists(atPath: path) {
            throw ValidationError("No such file or directory: \(path)")
        }

        if paths.count == 1 {
            let rows = computeRows(for: paths[0])
            let text = CsvFormattingUtils.buildFileText(
                rows: rows,
                sourcePaths: paths[0],
                writer: "csum-cli",
                version: "1.0"
            )

            FileHandle.standardOutput.write(Data(text.utf8))

            return
        }

        let explicit = unchanged || deleted || added || modified || moved || renamed
        let showUnchanged = unchanged
        let showDeleted = explicit ? deleted : true
        let showAdded = explicit ? added : true
        let showModified = explicit ? modified : true
        let showMoved = explicit ? moved : true
        let showRenamed = explicit ? renamed : true

        let first = try CsvCompare.loadRows(url: URL(fileURLWithPath: paths[0]), algorithm: algorithm)
        let second = try CsvCompare.loadRows(url: URL(fileURLWithPath: paths[1]), algorithm: algorithm)
        let report = CsvCompare.compare(first: first, second: second)

        var sections: [String] = []

        if showAdded && !report.added.isEmpty {
            sections.append(CsvFormattingUtils.formatSection(title: "Added", rows: report.added))
        }

        if showDeleted && !report.removed.isEmpty {
            sections.append(CsvFormattingUtils.formatSection(title: "Deleted", rows: report.removed))
        }

        if showMoved && !report.moved.isEmpty {
            sections.append(CsvFormattingUtils.formatPairSection(title: "Moved", pairs: report.moved))
        }

        if showRenamed && !report.renamed.isEmpty {
            sections.append(CsvFormattingUtils.formatPairSection(title: "Renamed", pairs: report.renamed))
        }

        if showModified && !report.changed.isEmpty {
            sections.append(CsvFormattingUtils.formatSection(title: "Modified", rows: report.changed.map { $0.new }))
        }

        if showUnchanged && !report.unchanged.isEmpty {
            sections.append(CsvFormattingUtils.formatSection(title: "Unchanged", rows: report.unchanged))
        }

        FileHandle.standardOutput.write(Data(sections.joined(separator: "").utf8))
    }

    private func computeRows(for path: String) -> [CsumCsvDataRow] {
        ChecksumCollector.collect(url: URL(fileURLWithPath: path), algorithm: algorithm)
    }
}

CsumCLI.main()
