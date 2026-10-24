import CoreTransferable
import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let csumChecksums = UTType(exportedAs: "com.djb.csum.csum-csv")
    static let csumComparison = UTType(exportedAs: "com.djb.csum.csum-compare-csv")
}

struct CsumCSVFile: Transferable {
    let text: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .csumChecksums) { file in
            try writeTemporaryCSV(text: file.text, fileName: file.fileName)
        }
        .suggestedFileName { $0.fileName }
    }
}

struct ComparisonCSVFile: Transferable {
    let text: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .csumComparison) { file in
            try writeTemporaryCSV(text: file.text, fileName: file.fileName)
        }
        .suggestedFileName { $0.fileName }
    }
}

struct CsumExport {
    enum Kind: Sendable {
        case checksums
        case comparison
    }

    let text: String
    let fileName: String
    let kind: Kind

    var contentType: UTType {
        switch kind {
        case .checksums:
            return .csumChecksums

        case .comparison:
            return .csumComparison
        }
    }

    var csvFile: CsumCSVFile {
        CsumCSVFile(text: text, fileName: fileName)
    }

    var comparisonFile: ComparisonCSVFile {
        ComparisonCSVFile(text: text, fileName: fileName)
    }
}

struct CsumTextDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.csumChecksums, .csumComparison]
    }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private func writeTemporaryCSV(text: String, fileName: String) throws -> SentTransferredFile {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let url = directory.appendingPathComponent(fileName)
    try text.write(to: url, atomically: true, encoding: .utf8)

    return SentTransferredFile(url)
}
