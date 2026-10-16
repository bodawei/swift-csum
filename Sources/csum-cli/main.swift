import ArgumentParser
import CsumController
import Foundation

extension ChecksumAlgorithm: ExpressibleByArgument {}

struct CsumCLI: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(
            commandName: "csum-cli",
            abstract: "Compute file checksums, or compare two checksum sources.",
            subcommands: [Check.self, Compare.self]
        )
    }
}

struct Check: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(abstract: "Write the checksums of a file or folder as .csum.csv.")
    }

    @Argument(help: "The file or folder to checksum.")
    var path: String

    @Option(name: [.customShort("a"), .long], help: "sha256, sha1, or md5.")
    var algorithm: ChecksumAlgorithm = .sha256

    func run() throws {
        do {
            try write()
        } catch {
            throw validationError(for: error)
        }
    }

    private func write() throws {
        let controller = CsumController(algorithm: algorithm, writer: CsumController.cliWriter)
        let result = try controller.calculateChecksums(at: URL(fileURLWithPath: path))

        FileHandle.standardOutput.write(Data(ChecksumFileCodec.render(result).utf8))
    }
}

struct Compare: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(abstract: "Compare two .csum.csv files, files, or folders.")
    }

    @Argument(help: "The first source: a .csum.csv file, a file, or a folder.")
    var first: String

    @Argument(help: "The second source: a .csum.csv file, a file, or a folder.")
    var second: String

    @Flag(name: .shortAndLong, help: "Include added entries.")
    var added = false

    @Flag(name: [.customShort("d"), .long], help: "Include removed entries.")
    var removed = false

    @Flag(name: [.customShort("c"), .long], help: "Include changed entries.")
    var changed = false

    @Flag(name: [.customShort("m"), .long], help: "Include moved entries.")
    var moved = false

    @Flag(name: .shortAndLong, help: "Include renamed entries.")
    var renamed = false

    @Flag(name: .shortAndLong, help: "Include unchanged entries.")
    var unchanged = false

    func run() throws {
        do {
            try write()
        } catch {
            throw validationError(for: error)
        }
    }

    private func write() throws {
        let controller = CsumController(algorithm: .sha256, writer: CsumController.cliWriter)
        let comparison = try controller.compare(
            first: URL(fileURLWithPath: first),
            second: URL(fileURLWithPath: second)
        )

        let text = ComparisonFileCodec.render(comparison, sections: selectedSections)

        FileHandle.standardOutput.write(Data(text.utf8))
    }

    private var selectedSections: [ComparisonSection] {
        let selected: [ComparisonSection?] = [
            added ? .added : nil,
            removed ? .removed : nil,
            changed ? .changed : nil,
            moved ? .moved : nil,
            renamed ? .renamed : nil,
            unchanged ? .unchanged : nil
        ]
        let explicit = selected.compactMap { $0 }

        guard explicit.isEmpty else {
            return explicit
        }

        return ComparisonSection.allCases.filter { $0 != .unchanged }
    }
}

private func validationError(for error: Error) -> Error {
    guard let error = error as? CsumError else {
        return error
    }

    switch error {
    case .notFound(let path):
        return ValidationError("No such file or directory: \(path)")
    case .sourceUnreadable(let path):
        return ValidationError("Cannot read \(path).")
    case .malformedFile(let path, let reason):
        return ValidationError("\(sourceName(path)) is not a valid .csum.csv file: \(describe(reason)).")
    case .unsupportedFormatVersion(let found, let expected):
        return ValidationError("Unsupported .csum.csv format version \(found); this tool reads and writes \(expected).")
    case .algorithmMismatch(let first, let second):
        return ValidationError("Cannot compare \(first.rawValue) checksums with \(second.rawValue) checksums.")
    }
}

private func sourceName(_ path: String) -> String {
    path.isEmpty ? "The input" : path
}

private func describe(_ reason: MalformedFileReason) -> String {
    switch reason {
    case .missingMetadata:
        return "the metadata comments are missing or unusable"
    case .unparsableAlgorithm:
        return "the algorithm is not sha256, sha1, or md5"
    case .unparsableSourceKind(let source):
        return "the \(source) source kind is unknown"
    case .rowOutsideSections(let row):
        return "row \(row) is not inside a section"
    case .unexpectedColumns(let section, let expected, let found):
        return "the \(section) section has \(found) columns where \(expected) are expected"
    case .wrongFieldCount(let section, let row, let expected, let found):
        return "row \(row) of the \(section) section has \(found) fields where \(expected) are expected"
    case .unparsableSize(let section, let row):
        return "row \(row) of the \(section) section has an unreadable size"
    case .unparsableTimestamp(let section, let row):
        return "row \(row) of the \(section) section has an unreadable timestamp"
    case .unparsableOutcome(let section, let row):
        return "row \(row) of the \(section) section has an unreadable checksum"
    case .unterminatedQuote:
        return "a quoted field is never closed"
    }
}

CsumCLI.main()
