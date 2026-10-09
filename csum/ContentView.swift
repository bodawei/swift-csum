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
    private let columnTitles = ["Filename", "Checksum", "Algorithm", "Size", "Created", "Modified", "Path"]

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
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        ForEach(columnTitles, id: \.self) { title in
                            tableCell(Text(title).font(.caption.bold()))
                        }
                    }
                    GridRow {
                        tableCell(Text(item.name).font(.caption))
                        tableCell(Text(item.digest).font(.system(.caption, design: .monospaced)))
                        tableCell(Text(item.algorithm.rawValue).font(.caption))
                        tableCell(Text(String(item.size)).font(.caption))
                        tableCell(Text(timestampString(item.creationDate)).font(.system(.caption, design: .monospaced)))
                        tableCell(Text(timestampString(item.modificationDate)).font(.system(.caption, design: .monospaced)))
                        tableCell(Text(item.path).font(.system(.caption, design: .monospaced)))
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            HStack {
                Button("Copy Row") {
                    #if os(iOS)
                    UIPasteboard.general.string = tsvLine(for: item)
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(tsvLine(for: item), forType: .string)
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

    private func tableCell<Content: View>(_ content: Content) -> some View {
        content
            .padding(6)
            .frame(minWidth: 70, alignment: .leading)
            .lineLimit(1)
            .textSelection(.enabled)
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.4)))
    }

    private func timestampString(_ date: Date?) -> String {
        date.map { String(Int64($0.timeIntervalSince1970)) } ?? ""
    }

    private func tsvLine(for item: FileChecksumResult) -> String {
        [
            item.name,
            item.digest,
            item.algorithm.rawValue,
            String(item.size),
            timestampString(item.creationDate),
            timestampString(item.modificationDate),
            item.path
        ].joined(separator: "\t")
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
