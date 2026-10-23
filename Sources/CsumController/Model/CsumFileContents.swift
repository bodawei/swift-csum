import Foundation

public enum CsumFileContents: Sendable {
    case checksums(ChecksumResult)
    case table(CsvTable)
}
