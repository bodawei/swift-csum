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
}

struct ContentView: View {
    @State private var algorithm: ChecksumAlgorithm = .sha256
    @State private var isImporting = false
    @State private var isComputing = false
    @State private var result: FileChecksumResult?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Algorithm", selection: $algorithm) {
                    ForEach(ChecksumAlgorithm.allCases, id: \.self) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isComputing)

                Spacer()

                if isComputing {
                    ProgressView("Computing checksum…")
                } else if let result {
                    resultCard(result)
                } else {
                    Text("Choose a file to compute its checksum.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button(result == nil ? "Choose File…" : "Choose Another File…") {
                    isImporting = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(isComputing)
            }
            .padding()
            .navigationTitle("Checksum")
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data]) { picked in
                switch picked {
                case .success(let url):
                    computeChecksum(of: url)
                case .failure(let error):
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
    private func resultCard(_ item: FileChecksumResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledRow("File", value: item.name, monospaced: false)
            labeledRow("Path", value: item.path, monospaced: true)
            labeledRow("Size", value: ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file), monospaced: false)
            if let creationDate = item.creationDate {
                labeledRow("Created", value: creationDate.formatted(date: .abbreviated, time: .shortened), monospaced: false)
            }
            if let modificationDate = item.modificationDate {
                labeledRow("Modified", value: modificationDate.formatted(date: .abbreviated, time: .shortened), monospaced: false)
            }
            labeledRow("Algorithm", value: item.algorithm.displayName, monospaced: false)
            labeledRow("Checksum", value: item.digest, monospaced: true)
            HStack {
                Button("Copy Checksum") {
                    #if os(iOS)
                    UIPasteboard.general.string = item.digest
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.digest, forType: .string)
                    #endif
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func labeledRow(_ title: String, value: String, monospaced: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
        }
    }

    private func computeChecksum(of url: URL) {
        isComputing = true
        let selectedAlgorithm = algorithm
        Task.detached(priority: .userInitiated) {
            let outcome: Result<FileChecksumResult, Error> = Result {
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                let digest = try ChecksumCalculator.checksum(of: url, algorithm: selectedAlgorithm)
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
                return FileChecksumResult(
                    name: url.lastPathComponent,
                    path: url.path,
                    size: Int64(values.fileSize ?? 0),
                    creationDate: values.creationDate,
                    modificationDate: values.contentModificationDate,
                    algorithm: selectedAlgorithm,
                    digest: digest
                )
            }
            await MainActor.run {
                isComputing = false
                switch outcome {
                case .success(let item):
                    result = item
                case .failure(let error):
                    presentError(error)
                }
            }
        }
    }

    private func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
