import CsumController
import SwiftUI

struct FileResultView: View {
    let model: FileSectionModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    share
                }
            }
            .onChange(of: model.showsSpinner) { _, shows in
                guard shows else {
                    return
                }

                AccessibilityNotification.Announcement("Checksumming…").post()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            Color.clear
        case .running:
            if model.showsSpinner {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel("Checksumming…")
            } else {
                Color.clear
            }
        case .loaded(let result):
            FileDetails(result: result)
        case .failed(let message):
            ErrorStateView(message: message)
        }
    }

    @ViewBuilder
    private var share: some View {
        if let export = model.export {
            ShareLink(item: export, preview: SharePreview(export.fileName)) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } else {
            Button {
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(true)
        }
    }
}

private struct FileDetails: View {
    let result: ChecksumResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                MetadataStrip(
                    path: result.metadata.root,
                    detail:
                        "Computed \(Format.timestamp(result.metadata.computedAt)) · Format \(result.metadata.formatVersion)"
                )

                KeyValueCard(rows: rows)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    private var rows: [(label: LocalizedStringKey, value: String)] {
        guard let entry = result.entries.first else {
            return []
        }

        return [
            ("Checksum", Format.checksum(entry)),
            ("Algorithm", result.metadata.algorithm.displayName),
            ("Size", Format.size(entry.size)),
            ("Created", Format.timestamp(entry.created)),
            ("Modified", Format.timestamp(entry.modified)),
            ("Path", entry.path),
        ]
    }
}
