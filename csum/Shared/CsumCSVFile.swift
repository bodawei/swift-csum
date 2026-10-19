import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct CsumCSVFile: Transferable {
    let text: String
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)

            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)

            let url = directory.appendingPathComponent(file.fileName)
            try file.text.write(to: url, atomically: true, encoding: .utf8)

            return SentTransferredFile(url)
        }
        .suggestedFileName { $0.fileName }
    }
}
