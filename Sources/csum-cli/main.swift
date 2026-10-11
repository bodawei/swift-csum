import ArgumentParser
import ChecksumCore
import Foundation

extension ChecksumAlgorithm: ExpressibleByArgument {}

let csvHeader = "Filename,Checksum,Algorithm,Size,Created,Modified,Path"

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
            let text = csvFileText(rows: rows, source: paths[0])
            FileHandle.standardOutput.write(Data(text.utf8))
            return
        }

        let explicit = unchanged || deleted || added || modified
        let showUnchanged = unchanged
        let showDeleted = explicit ? deleted : true
        let showAdded = explicit ? added : true
        let showModified = explicit ? modified : true

        let first = try resolve(paths[0])
        let second = try resolve(paths[1])
        let report = CsvCompare.compare(first: first, second: second)

        var sections: [String] = []
        if showAdded {
            var rows = report.added.map(csvRowValues)
            rows += report.moved.map { csvRowValues($0.to) }
            sections.append(sectionText(title: "Added", rows: rows))
        }
        if showDeleted {
            var rows = report.removed.map(csvRowValues)
            rows += report.moved.map { csvRowValues($0.from) }
            sections.append(sectionText(title: "Deleted", rows: rows))
        }
        if showModified {
            sections.append(sectionText(title: "Modified", rows: report.changed.map { csvRowValues($0.new) }))
        }
        if showUnchanged {
            sections.append(sectionText(title: "Unchanged", rows: report.unchanged.map(csvRowValues)))
        }
        FileHandle.standardOutput.write(Data(sections.joined(separator: "").utf8))
    }

    private func resolve(_ path: String) throws -> [CsvRow] {
        if path.lowercased().hasSuffix(".csum.csv") {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            return CsvCompare.rows(from: String(decoding: data, as: UTF8.self))
        }
        return try computeRows(for: path)
    }

    private func computeRows(for path: String) throws -> [CsvRow] {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ValidationError("No such file or directory: \(path)")
        }
        return ChecksumCollector.collect(url: URL(fileURLWithPath: path), algorithm: algorithm)
    }

    private func csvRowValues(_ row: CsvRow) -> [String] {
        [row.filename, row.checksum, row.algorithm, row.size, row.created, row.modified, row.path]
    }

    private func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private func csvLine(_ values: [String]) -> String {
        values.map(csvField).joined(separator: ",")
    }

    private func sectionText(title: String, rows: [[String]]) -> String {
        let body = rows.map(csvLine).joined(separator: "\r\n")
        return "# \(title)\r\n\(csvHeader)\r\n\(body)\r\n"
    }

    private func csvFileText(rows: [CsvRow], source: String) -> String {
        let date = ISO8601DateFormatter().string(from: Date())
        let comments = [
            "# written by csum-cli v1.0.",
            "# Checksums of files at \(source) done on \(date)"
        ]
        let body = rows.map { csvLine(csvRowValues($0)) }.joined(separator: "\r\n")
        return (comments + [csvHeader, body]).joined(separator: "\r\n") + "\r\n"
    }
}

CsumCLI.main()
