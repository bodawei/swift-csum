import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif
import ChecksumCore

struct FileChecksumResult: Sendable {
    let name: String
    let path: String
    let size: Int64
    let creationDate: Date?
    let modificationDate: Date?
    let algorithm: ChecksumAlgorithm
    let digest: String
    let errorMessage: String?
}

struct ContentView: View {
    private let columnTitles = ["Filename", "Checksum", "Algorithm", "Size", "Created", "Modified", "Path"]
    private let columnWidths: [CGFloat] = [170, 470, 90, 110, 100, 100, 340]

    @AppStorage("checksumAlgorithm") private var algorithmRawValue = ChecksumAlgorithm.sha256.rawValue
    @State private var isImportingFiles = false
    @State private var isImportingFolder = false
    @State private var isComputing = false
    @State private var processedFiles = 0
    @State private var totalFiles = 0
    @State private var result: [FileChecksumResult]?
    @State private var errorMessage: String?
    @State private var showError = false

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

                HStack(spacing: 16) {
                    #if os(iOS)
                    Picker("Algorithm", selection: algorithmBinding) {
                        ForEach(ChecksumAlgorithm.allCases, id: \.self) { item in
                            Text(item.displayName).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(isComputing)
                    #endif

                    Button("Choose Files…") {
                        #if os(macOS)
                        presentOpenPanel(selectFolders: false)
                        #else
                        isImportingFiles = true
                        #endif
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isComputing)

                    Button("Choose Folder…") {
                        #if os(macOS)
                        presentOpenPanel(selectFolders: true)
                        #else
                        isImportingFolder = true
                        #endif
                    }
                    .buttonStyle(.bordered)
                    .disabled(isComputing)
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
            #endif
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
            presentError(error)
        }
    }
    #endif

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
                    ForEach(items, id: \.path) { item in
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
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
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

    private func tsvLine(for item: FileChecksumResult) -> String {
        let checksum = item.errorMessage.map { "Error: \($0)" } ?? item.digest
        return [
            item.name,
            checksum,
            item.algorithm.rawValue,
            String(item.size),
            timestampString(item.creationDate),
            timestampString(item.modificationDate),
            item.path
        ].joined(separator: "\t")
    }

    private func computeChecksums(of urls: [URL]) {
        isComputing = true
        processedFiles = 0
        totalFiles = 0
        let selectedAlgorithm = algorithm
        Task.detached(priority: .userInitiated) {
            var accessed: [URL] = []
            var rows: [FileChecksumResult] = []
            var failure: Error?
            do {
                var files: [URL] = []
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        accessed.append(url)
                    }
                    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                    if values.isSymbolicLink == true {
                        continue
                    }
                    if values.isDirectory == true {
                        files.append(contentsOf: Self.enumerateFiles(in: url))
                    } else {
                        files.append(url)
                    }
                }
                let sorted = files.sorted { $0.path < $1.path }
                await MainActor.run {
                    totalFiles = sorted.count
                }
                for index in sorted.indices {
                    rows.append(Self.row(for: sorted[index], algorithm: selectedAlgorithm))
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

    private nonisolated static func row(for url: URL, algorithm: ChecksumAlgorithm) -> FileChecksumResult {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
        do {
            let digest = try ChecksumCalculator.checksum(of: url, algorithm: algorithm)
            return FileChecksumResult(
                name: url.lastPathComponent,
                path: url.path,
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
                path: url.path,
                size: Int64(values?.fileSize ?? 0),
                creationDate: values?.creationDate,
                modificationDate: values?.contentModificationDate,
                algorithm: algorithm,
                digest: "",
                errorMessage: error.localizedDescription
            )
        }
    }

    private func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
