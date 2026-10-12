import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif
import ChecksumCore

struct ContentView: View {
    @AppStorage("checksumAlgorithm") private var algorithmRawValue = ChecksumAlgorithm.sha256.rawValue
    @State private var isImportingFiles = false
    @State private var isImportingFolder = false
    @State private var isImportingCsvSlot = false
    @State private var isImportingFolderSlot = false
    @State private var pendingCsvSlot: Int?
    @State private var pendingFolderSlot: Int?
    @State private var compareSources: [CompareSource?] = [nil, nil]
    @State private var isComputing = false
    @State private var isComparing = false
    @State private var processedFiles = 0
    @State private var totalFiles = 0
    @State private var result: [CsvRow]?
    @State private var comparison: CsvComparison?
    @State private var sourcePaths = ""
    @State private var exportDocument: CSVDocument?
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var fileDropTargeted = false
    @State private var folderDropTargeted = false

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

                statusArea

                Spacer()

                VStack(spacing: 12) {
                    checksumButtons
                    CompareFormView(
                        sources: $compareSources,
                        isBusy: isComputing || isComparing,
                        onPickCsv: requestCsvPick,
                        onPickFolder: requestFolderPick,
                        onCompare: runComparison
                    )
                }
            }
            .padding()
            .navigationTitle("Checksum")
            .onOpenURL { url in
                guard url.path.lowercased().hasSuffix(".csum.csv") else {
                    return
                }

                compareSources[0] = CompareSource(
                    name: url.lastPathComponent,
                    path: url.path,
                    url: url,
                    isFolder: false
                )
            }
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
                isPresented: $isImportingCsvSlot,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { picked in
                handleCsvSlotPicked(picked)
            }
            .fileImporter(
                isPresented: $isImportingFolderSlot,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { picked in
                handleFolderSlotPicked(picked)
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

    @ViewBuilder
    private var statusArea: some View {
        if isComputing {
            ProgressView("Computing checksum \(processedFiles) of \(totalFiles)…")
        } else if isComparing {
            ProgressView("Comparing…")
        } else if let comparison {
            ReportView(comparison: comparison)
        } else if let rows = result {
            if rows.isEmpty {
                Text("No files found.")
                    .foregroundStyle(.secondary)
            } else {
                ResultTableView(items: rows, onCopy: copyRows, onSave: saveCsv)
            }
        } else {
            Text("Checksum a file or folder, or fill in two sources below and compare.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var checksumButtons: some View {
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

            Button("Checksum File") {
                #if os(macOS)
                FileDialogs.pickSources(
                    selectFolders: false,
                    algorithm: algorithm,
                    algorithmChanged: { algorithmRawValue = $0.rawValue },
                    completion: computeChecksums
                )
                #else
                isImportingFiles = true
                #endif
            }
            .buttonStyle(.borderedProminent)
            .disabled(isComputing || isComparing)
            .dropDestination(for: URL.self) { urls, _ in
                computeChecksums(of: urls)

                return true
            } isTargeted: {
                fileDropTargeted = $0
            }
            .dropHighlight(fileDropTargeted)

            Button("Checksum Folder") {
                #if os(macOS)
                FileDialogs.pickSources(
                    selectFolders: true,
                    algorithm: algorithm,
                    algorithmChanged: { algorithmRawValue = $0.rawValue },
                    completion: computeChecksums
                )
                #else
                isImportingFolder = true
                #endif
            }
            .buttonStyle(.borderedProminent)
            .disabled(isComputing || isComparing)
            .dropDestination(for: URL.self) { urls, _ in
                computeChecksums(of: urls)

                return true
            } isTargeted: {
                folderDropTargeted = $0
            }
            .dropHighlight(folderDropTargeted)
        }
    }

    private func requestCsvPick(_ index: Int) {
        #if os(macOS)
        FileDialogs.pickCsv { url in
            guard let url else {
                return
            }

            compareSources[index] = CompareSource(
                name: url.lastPathComponent,
                path: url.path,
                url: url,
                isFolder: false
            )
        }
        #else
        pendingCsvSlot = index
        isImportingCsvSlot = true
        #endif
    }

    private func requestFolderPick(_ index: Int) {
        #if os(macOS)
        FileDialogs.pickFolder { url in
            guard let url else {
                return
            }

            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

            compareSources[index] = CompareSource(
                name: url.lastPathComponent,
                path: url.path,
                url: url,
                isFolder: isDirectory
            )
        }
        #else
        pendingFolderSlot = index
        isImportingFolderSlot = true
        #endif
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

    private func handleCsvSlotPicked(_ picked: Result<[URL], Error>) {
        guard let slot = pendingCsvSlot else {
            return
        }

        guard case .success(let urls) = picked, let url = urls.first else {
            if case .failure(let error) = picked, !isUserCancelled(error) {
                presentError(error)
            }

            return
        }

        compareSources[slot] = CompareSource(name: url.lastPathComponent, path: url.path, url: url, isFolder: false)
    }

    private func handleFolderSlotPicked(_ picked: Result<[URL], Error>) {
        guard let slot = pendingFolderSlot else {
            return
        }

        guard case .success(let urls) = picked, let url = urls.first else {
            if case .failure(let error) = picked, !isUserCancelled(error) {
                presentError(error)
            }

            return
        }

        compareSources[slot] = CompareSource(name: url.lastPathComponent, path: url.path, url: url, isFolder: true)
    }
    #endif

    private func computeChecksums(of urls: [URL]) {
        isComputing = true
        processedFiles = 0
        totalFiles = 0
        sourcePaths = urls.map(\.path).joined(separator: ", ")

        let selectedAlgorithm = algorithm

        Task.detached(priority: .userInitiated) {
            var rows: [CsvRow] = []
            var failure: Error?

            do {
                rows = try ChecksumCollector.collectAll(urls: urls, algorithm: selectedAlgorithm) { done, total in
                    guard done == total || done % 37 == 1 else {
                        return
                    }

                    Task { @MainActor in
                        processedFiles = done
                        totalFiles = total
                    }
                }
            } catch {
                failure = error
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

    private func runComparison() {
        guard let first = compareSources[0], let second = compareSources[1] else {
            return
        }

        isComparing = true

        let selectedAlgorithm = algorithm

        Task.detached(priority: .userInitiated) {
            var built: CsvComparison?
            var failure: Error?

            do {
                let firstRows = try CsvCompare.resolve(url: first.url, algorithm: selectedAlgorithm)
                let secondRows = try CsvCompare.resolve(url: second.url, algorithm: selectedAlgorithm)

                built = CsvComparison(
                    firstName: first.name,
                    secondName: second.name,
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

    private func copyRows() {
        guard let result else {
            return
        }

        let text = CsvFormattingUtils.generateTsvText(rows: result)

        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private func saveCsv() {
        guard let result else {
            return
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"

        exportDocument = CSVDocument(
            text: CsvFormattingUtils.buildFileText(
                rows: result,
                sourcePaths: sourcePaths,
                writer: "csum",
                version: version
            )
        )
        isExporting = true
    }

    private func isUserCancelled(_ error: Error) -> Bool {
        (error as NSError).code == NSUserCancelledError
    }

    private func presentMessage(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func presentError(_ error: Error) {
        presentMessage(error.localizedDescription)
    }
}
