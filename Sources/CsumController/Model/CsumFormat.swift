public enum CsumFormat {
    public static let version = "1.0"
    public static let toolVersion = "1.0"
    public static let checksumFileExtension = "csum.csv"
    public static let comparisonFileExtension = "csum-compare.csv"
    public static let comparisonFileName = "Comparison.csum-compare.csv"

    public static func strippingFileExtension(
        _ fileExtension: String,
        from name: String
    ) -> String? {
        let suffix = ".\(fileExtension)"

        guard name.lowercased().hasSuffix(suffix.lowercased()) else {
            return nil
        }

        return String(name.dropLast(suffix.count))
    }
}
