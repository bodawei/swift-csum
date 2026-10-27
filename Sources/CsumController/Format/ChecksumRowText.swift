import Foundation

public enum ChecksumRowText {
    public static func line(for entry: ChecksumEntry) -> String {
        EntryRowCodec.row(for: entry)
            .map(Csv.formatField)
            .joined(separator: ",")
    }
}
