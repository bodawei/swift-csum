import ArgumentParser
import ChecksumCore
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

    @Option(name: .long, help: "The checksum algorithm to use when computing.")
    var algorithm: ChecksumAlgorithm = .sha256

    @Flag(name: .short, help: "Include unchanged entries in compare output.")
    var unchanged = false

    @Flag(name: .short, help: "Include deleted entries in compare output.")
    var deleted = false

    @Flag(name: .short, help: "Include added entries in compare output.")
    var added = false

    @Flag(name: .short, help: "Include modified entries in compare output.")
    var modified = false

    func run() throws {
        guard (1...2).contains(paths.count) else {
            throw ValidationError("Provide one path to checksum, or two to compare.")
        }

        if paths.count == 1 {
            let rows = try computeRows(for: paths[0])
            let text = CsvFormatter.fileText(
                rows: rows,
                sourcePaths: paths[0],
                writer: "csum-cli",
                version: "1.0"
            )

            FileHandle.standardOutput.write(Data(text.utf8))

            return
        }

        let explicit = unchanged || deleted || added || modified
        let showUnchanged = unchanged
        let showDeleted = explicit ? deleted : true
        let showAdded = explicit ? added : true
        let showModified = explicit ? modified : true

        let first = try CsvCompare.resolve(url: URL(fileURLWithPath: paths[0]), algorithm: algorithm)
        let second = try CsvCompare.resolve(url: URL(fileURLWithPath: paths[1]), algorithm: algorithm)
        let report = CsvCompare.compare(first: first, second: second)

        var sections: [String] = []

        if showAdded {
            var rows = report.added
            rows += report.moved.map { $0.to }
            sections.append(CsvFormatter.section(title: "Added", rows: rows))
        }

        if showDeleted {
            var rows = report.removed
            rows += report.moved.map { $0.from }
            sections.append(CsvFormatter.section(title: "Deleted", rows: rows))
        }

        if showModified {
            sections.append(CsvFormatter.section(title: "Modified", rows: report.changed.map { $0.new }))
        }

        if showUnchanged {
            sections.append(CsvFormatter.section(title: "Unchanged", rows: report.unchanged))
        }

        FileHandle.standardOutput.write(Data(sections.joined(separator: "").utf8))
    }

    private func computeRows(for path: String) throws -> [CsvRow] {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("No such file or directory: \(path)")
        }

        return ChecksumCollector.collect(url: URL(fileURLWithPath: path), algorithm: algorithm)
    }
}

CsumCLI.main()
