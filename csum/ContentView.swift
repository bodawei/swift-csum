import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif
import ChecksumCore

struct FileChecksumResult: Sendable {
    let name: String
    let path: String
    let fullPath: String
    let size: Int64
    let creationDate: Date?
    let modificationDate: Date?
    let algorithm: ChecksumAlgorithm
    let digest: String
    let errorMessage: String?
}

struct CsvComparison: Sendable {
    let firstName: String
    let secondName: String
    let report: ComparisonReport
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.commaSeparatedText]
    }

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(("\u{FEFF}" + text).utf8))
    }
}

struct ContentView: View {
    private let columnTitles = ["Filename", "Checksum", "Algorithm", "Size", "Created", "Modified", "Path"]
    private let columnWidths: [CGFloat] = [170, 470, 90, 110, 100, 100, 340]
    private let standardColumns: [(title: String, width: CGFloat)]

    @AppStorage("checksumAlgorithm") private var algorithmRawValue = ChecksumAlgorithm.sha256.rawValue
    @State private var isImportingFiles = false
    @State private var isImportingFolder = false
    @State private var isImportingFirstCsv = false
    @State private var isImportingSecondCsv = false
    @State private var stagedFirstCsv: URL?
    @State private var isComputing = false
    @State private var isComparing = false
    @State private var processedFiles = 0
    @State private var totalFiles = 0
    @State private var result: [FileChecksumResult]?
    @State private var comparison: CsvComparison?
    @State private var sourcePaths = ""
    @State private var exportDocument: CSVDocument?
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var showError = false

    init() {
        standardColumns = Array(zip(columnTitles, columnWidths))
    }

    private var tableWidth: CGFloat {
        columnWidths.reduce(0, +)
    }

    private var algorithm: ChecksumAlgorithm {
        ChecksumAlgorithm(rawValue: algorithmRawValue) ?? .sha256
    }

    private var algorithmBinding: Binding<ChecksumAlgorithm> {
        Binding(
            get: { ChecksumAlgorithm(rawValue: algorithmRawValue) ?? .sha256 },
            set: { algorithmRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                if isComputing {
                    ProgressView("Computing checksum \(processedFiles) of \(totalFiles)…")
                } else if isComparing {
                    ProgressView("Comparing CSVs…")
                } else if let comparison {
                    reportView(comparison)
                } else if let rows = result {
                    if rows.isEmpty {
                        Text("No files found.")
                            .foregroundStyle(.secondary)
                    } else {
                        resultCard(rows)
                    }
                } else {
                    Text("Choose files or a folder to compute checksums.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        #if os(iOS)
                        Picker("Algorithm", selection: algorithmBinding) {
                            ForEach(ChecksumAlgorithm.allCases, id: \.self) { item in
                                Text(item.displayName).tag(item)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(isComputing || isComparing)
                        #endif

                        Button("Choose Files…") {
                            #if os(macOS)
                            presentOpenPanel(selectFolders: false)
                            #else
                            isImportingFiles = true
                            #endif
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isComputing || isComparing)

                        Button("Choose Folder…") {
                            #if os(macOS)
                            presentOpenPanel(selectFolders: true)
                            #else
                            isImportingFolder = true
                            #endif
                        }
                        .buttonStyle(.bordered)
                        .disabled(isComputing || isComparing)
                    }

                    Button("Compare CSVs…") {
                        #if os(macOS)
                        presentCompareFlow()
                        #else
                        isImportingFirstCsv = true
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .disabled(isComputing || isComparing)
                }
            }
            .padding()
            .navigationTitle("Checksum")
            #if os(iOS)
            .fileImporter(
                isPresented: $isImportingFiles,
                allowedContentTypes: [.item],
                allowsMultipleSelection: true
            ) { picked in
                handlePicked(picked)
            }
            .fileImporter(
                isPresented: $isImportingFolder,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: true
            ) { picked in
                handlePicked(picked)
            }
            .fileImporter(
                isPresented: $isImportingFirstCsv,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { picked in
                handleFirstCsvPicked(picked)
            }
            .fileImporter(
                isPresented: $isImportingSecondCsv,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { picked in
                handleSecondCsvPicked(picked)
            }
            #endif
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "checksums.csum"
            ) { exportResult in
                if case .failure(let error) = exportResult {
                    presentError(error)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error.")
            }
        }
    }

    #if os(iOS)
    private func handlePicked(_ picked: Result<[URL], Error>) {
        switch picked {
        case .success(let urls):
            computeChecksums(of: urls)
        case .failure(let error):
            if !isUserCancelled(error) {
                presentError(error)
            }
        }
    }

    private func handleFirstCsvPicked(_ picked: Result<[URL], Error>) {
        guard case .success(let urls) = picked, let url = urls.first else {
            if case .failure(let error) = picked, !isUserCancelled(error) {
                presentError(error)
            }
            return
        }
        stagedFirstCsv = url
        isImportingSecondCsv = true
    }

    private func handleSecondCsvPicked(_ picked: Result<[URL], Error>) {
        guard case .success(let urls) = picked, let url = urls.first else {
            stagedFirstCsv = nil
            if case .failure(let error) = picked, !isUserCancelled(error) {
                presentError(error)
            }
            return
        }
        if let first = stagedFirstCsv {
            stagedFirstCsv = nil
            compareCsv(at: first, second: url)
        }
    }
    #endif

    private func isUserCancelled(_ error: Error) -> Bool {
        (error as NSError).code == NSUserCancelledError
    }

    #if os(macOS)
    private func presentOpenPanel(selectFolders: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !selectFolders
        panel.canChooseDirectories = selectFolders
        panel.allowsMultipleSelection = true
        let algorithms = ChecksumAlgorithm.allCases
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: algorithms.map(\.displayName))
        popup.selectItem(at: max(0, algorithms.firstIndex(of: algorithm) ?? 0))
        let label = NSTextField(labelWithString: "Algorithm:")
        let accessory = NSStackView(views: [label, popup])
        accessory.frame = NSRect(x: 0, y: 0, width: accessory.fittingSize.width, height: 28)
        panel.accessoryView = accessory
        guard let window = NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first else {
            return
        }
        panel.beginSheetModal(for: window) { [popup] response in
            guard response == .OK else {
                return
            }
            let index = max(0, min(popup.indexOfSelectedItem, algorithms.count - 1))
            algorithmRawValue = algorithms[index].rawValue
            computeChecksums(of: panel.urls)
        }
    }

    private func presentCsvPicker(message: String, completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.message = message
        guard let window = NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first else {
            completion(nil)
            return
        }
        panel.beginSheetModal(for: window) { response in
            completion(response == .OK ? panel.url : nil)
        }
    }

    private func presentCompareFlow() {
        presentCsvPicker(message: "Choose the OLDER .csum.csv file") { first in
            guard let first else {
                return
            }
            presentCsvPicker(message: "Choose the NEWER .csum.csv file") { second in
                guard let second else {
                    return
                }
                compareCsv(at: first, second: second)
            }
        }
    }
    #endif

    @ViewBuilder
    private func resultCard(_ items: [FileChecksumResult]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(Array(columnTitles.enumerated()), id: \.offset) { index, title in
                            tableCell(Text(title).font(.caption.bold()), width: columnWidths[index])
                        }
                    }
                    ForEach(items, id: \.fullPath) { item in
                        HStack(spacing: 0) {
                            tableCell(Text(item.name).font(.caption), width: columnWidths[0])
                            checksumCell(item, width: columnWidths[1])
                            tableCell(Text(item.algorithm.rawValue).font(.caption), width: columnWidths[2])
                            tableCell(Text(String(item.size)).font(.caption), width: columnWidths[3])
                            tableCell(Text(timestampString(item.creationDate)).font(.system(.caption, design: .monospaced)), width: columnWidths[4])
                            tableCell(Text(timestampString(item.modificationDate)).font(.system(.caption, design: .monospaced)), width: columnWidths[5])
                            tableCell(Text(item.path).font(.system(.caption, design: .monospaced)), width: columnWidths[6])
                        }
                    }
                }
                .frame(width: tableWidth)
            }
            .frame(maxHeight: 400)
            HStack {
                Button("Copy Rows") {
                    let text = items.map { tsvLine(for: $0) }.joined(separator: "\n")
                    #if os(iOS)
                    UIPasteboard.general.string = text
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    #endif
                }
                .buttonStyle(.bordered)
                Button("Save CSV…") {
                    exportDocument = CSVDocument(text: csvText(for: items))
                    isExporting = true
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func reportView(_ comparison: CsvComparison) -> some View {
        let report = comparison.report
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Older: \(comparison.firstName) · Newer: \(comparison.secondName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("Unchanged \(report.unchanged.count) · Added \(report.added.count) · Removed \(report.removed.count) · Moved \(report.moved.count) · Changed \(report.changed.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if report.isEmpty {
                    Text("Nothing to compare.")
                        .foregroundStyle(.secondary)
                }
                if !report.unchanged.isEmpty {
                    groupSection("Unchanged", .green, report.unchanged.count) {
                        matrixTable(columns: standardColumns, rows: report.unchanged.map(standardMatrixRow))
                    }
                }
                if !report.added.isEmpty {
                    groupSection("Added", .blue, report.added.count) {
                        matrixTable(columns: standardColumns, rows: report.added.map(standardMatrixRow))
                    }
                }
                if !report.removed.isEmpty {
                    groupSection("Removed", .red, report.removed.count) {
                        matrixTable(columns: standardColumns, rows: report.removed.map(standardMatrixRow))
                    }
                }
                if !report.moved.isEmpty {
                    let columns: [(title: String, width: CGFloat)] = [
                        ("Filename", 170), ("Checksum", 470), ("Size", 110), ("From", 340), ("To", 340)
                    ]
                    groupSection("Moved", .orange, report.moved.count) {
                        matrixTable(columns: columns, rows: report.moved.map {
                            [$0.to.filename, $0.to.checksum, $0.to.size, $0.from.path, $0.to.path]
                        })
                    }
                }
                if !report.changed.isEmpty {
                    let columns: [(title: String, width: CGFloat)] = [
                        ("Filename", 170), ("Path", 340), ("Old Size", 110), ("New Size", 110),
                        ("Old Checksum", 470), ("New Checksum", 470)
                    ]
                    groupSection("Changed", .purple, report.changed.count) {
                        matrixTable(columns: columns, rows: report.changed.map {
                            [$0.new.filename, $0.new.path, $0.old.size, $0.new.size, $0.old.checksum, $0.new.checksum]
                        })
                    }
                }
            }
        }
        .frame(maxHeight: 420)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
    }

    private func groupSection<Content: View>(
        _ title: String,
        _ color: Color,
        _ count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) (\(count))")
                .font(.headline)
                .foregroundStyle(color)
            content()
        }
    }

    private func matrixTable(columns: [(title: String, width: CGFloat)], rows: [[String]]) -> some View {
        let total = columns.reduce(0) { $0 + $1.width }
        return ScrollView(.horizontal) {
            LazyVStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                        tableCell(Text(column.title).font(.caption.bold()), width: column.width)
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 0) {
                        ForEach(Array(row.enumerated()), id: \.offset) { cellIndex, value in
                            tableCell(Text(value).font(cellFont(columns[cellIndex].title)), width: columns[cellIndex].width)
                        }
                    }
                }
            }
            .frame(width: total)
        }
    }

    private func cellFont(_ title: String) -> Font {
        switch title {
        case "Checksum", "Path", "From", "To", "Old Checksum", "New Checksum", "Created", "Modified":
            return .system(.caption, design: .monospaced)
        default:
            return .caption
        }
    }

    private func standardMatrixRow(_ row: CsvRow) -> [String] {
        [row.filename, row.checksum, row.algorithm, row.size, row.created, row.modified, row.path]
    }

    @ViewBuilder
    private func checksumCell(_ item: FileChecksumResult, width: CGFloat) -> some View {
        if let errorMessage = item.errorMessage {
            tableCell(Text("Error: \(errorMessage)").font(.system(.caption, design: .monospaced)).foregroundStyle(.red), width: width)
        } else {
            tableCell(Text(item.digest).font(.system(.caption, design: .monospaced)), width: width)
        }
    }

    private func tableCell<Content: View>(_ content: Content, width: CGFloat) -> some View {
        content
            .padding(6)
            .frame(width: width, alignment: .leading)
            .lineLimit(1)
            .textSelection(.enabled)
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.4)))
    }

    private func timestampString(_ date: Date?) -> String {
        date.map { String(Int64($0.timeIntervalSince1970)) } ?? ""
    }

    private func fieldValues(for item: FileChecksumResult) -> [String] {
        let checksum = item.errorMessage.map { "Error: \($0)" } ?? item.digest
        return [
            item.name,
            checksum,
            item.algorithm.rawValue,
            String(item.size),
            timestampString(item.creationDate),
            timestampString(item.modificationDate),
            item.path
        ]
    }

    private func tsvLine(for item: FileChecksumResult) -> String {
        fieldValues(for: item).joined(separator: "\t")
    }

    private func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    private func csvLine(for item: FileChecksumResult) -> String {
        fieldValues(for: item).map(csvField).joined(separator: ",")
    }

    private func csvText(for items: [FileChecksumResult]) -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let date = Date.now.formatted(.iso8601)
        let comments = [
            "# written by csum v\(version).",
            "# Checksums of files at \(sourcePaths) done on \(date)"
        ]
        let header = columnTitles.map(csvField).joined(separator: ",")
        return (comments + [header] + items.map(csvLine)).joined(separator: "\r\n")
    }

    private func compareCsv(at first: URL, second: URL) {
        isComparing = true
        Task.detached(priority: .userInitiated) {
            var built: CsvComparison?
            var failure: Error?
            do {
                let firstRows = try Self.readCsv(at: first)
                let secondRows = try Self.readCsv(at: second)
                built = CsvComparison(
                    firstName: first.lastPathComponent,
                    secondName: second.lastPathComponent,
                    report: CsvCompare.compare(first: firstRows, second: secondRows)
                )
            } catch {
                failure = error
            }
            let finalBuilt = built
            let finalFailure = failure
            await MainActor.run {
                isComparing = false
                if let finalFailure {
                    presentError(finalFailure)
                } else if let finalBuilt {
                    result = nil
                    comparison = finalBuilt
                }
            }
        }
    }

    private nonisolated static func readCsv(at url: URL) throws -> [CsvRow] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        return CsvCompare.rows(from: String(decoding: data, as: UTF8.self))
    }

    private func computeChecksums(of urls: [URL]) {
        isComputing = true
        processedFiles = 0
        totalFiles = 0
        sourcePaths = urls.map(\.path).joined(separator: ", ")
        let selectedAlgorithm = algorithm
        Task.detached(priority: .userInitiated) {
            var accessed: [URL] = []
            var rows: [FileChecksumResult] = []
            var failure: Error?
            do {
                var files: [(url: URL, base: String?)] = []
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        accessed.append(url)
                    }
                    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    if values.isSymbolicLink == true {
                        continue
                    }
                    if values.isDirectory == true {
                        var base = url.path
                        if base.hasSuffix("/") && base.count > 1 {
                            base.removeLast()
                        }
                        for file in Self.enumerateFiles(in: url) {
                            files.append((file, base))
                        }
                    } else {
                        files.append((url, nil))
                    }
                }
                let sorted = files.sorted { $0.url.path < $1.url.path }
                await MainActor.run {
                    totalFiles = sorted.count
                }
                for index in sorted.indices {
                    rows.append(Self.row(for: sorted[index].url, algorithm: selectedAlgorithm, base: sorted[index].base))
                    if index % 37 == 0 {
                        let count = index + 1
                        await MainActor.run {
                            processedFiles = count
                        }
                    }
                }
                let finalCount = sorted.count
                await MainActor.run {
                    processedFiles = finalCount
                }
            } catch {
                failure = error
            }
            for url in accessed {
                url.stopAccessingSecurityScopedResource()
            }
            let finalRows = rows
            let finalFailure = failure
            await MainActor.run {
                isComputing = false
                comparison = nil
                if let finalFailure {
                    presentError(finalFailure)
                } else {
                    result = finalRows
                }
            }
        }
    }

    private nonisolated static func enumerateFiles(in folder: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ) else {
            return []
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true,
                  values.isDirectory != true else {
                continue
            }
            files.append(url)
        }
        return files
    }

    private nonisolated static func row(for url: URL, algorithm: ChecksumAlgorithm, base: String?) -> FileChecksumResult {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
        let path = displayPath(for: url.path, base: base)
        do {
            let digest = try ChecksumCalculator.checksum(of: url, algorithm: algorithm)
            return FileChecksumResult(
                name: url.lastPathComponent,
                path: path,
                fullPath: url.path,
                size: Int64(values?.fileSize ?? 0),
                creationDate: values?.creationDate,
                modificationDate: values?.contentModificationDate,
                algorithm: algorithm,
                digest: digest,
                errorMessage: nil
            )
        } catch {
            return FileChecksumResult(
                name: url.lastPathComponent,
                path: path,
                fullPath: url.path,
                size: Int64(values?.fileSize ?? 0),
                creationDate: values?.creationDate,
                modificationDate: values?.contentModificationDate,
                algorithm: algorithm,
                digest: "",
                errorMessage: error.localizedDescription
            )
        }
    }

    private nonisolated static func displayPath(for path: String, base: String?) -> String {
        guard let base else {
            return path
        }
        let prefix = base.hasSuffix("/") ? base : base + "/"
        if path.hasPrefix(prefix) {
            return "./" + String(path.dropFirst(prefix.count))
        }
        return path
    }

    private func presentMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func presentError(_ error: Error) {
        presentMessage(error.localizedDescription)
    }
}
