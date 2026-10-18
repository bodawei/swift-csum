import Foundation
import CsumController

struct CompareSource: Sendable {
    let name: String
    let path: String
    let url: URL
    let isFolder: Bool

    var summary: String {
        "\(name) — \(path)"
    }
}

struct CsvComparison: Sendable {
    let firstName: String
    let secondName: String
    let report: ComparisonReport
}
