import CsumController
import SwiftUI

struct FolderResultView: View {
    let model: FolderSectionModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    share
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            Color.clear
        case .running:
            FolderProgress(progress: model.progress)
        case .loaded(let result):
            FolderResults(result: result)
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

private struct FolderProgress: View {
    let progress: (done: Int, total: Int)?

    var body: some View {
        VStack(spacing: 12) {
            Text("Checksumming Folder…")

            if let progress {
                ProgressView(value: Double(progress.done), total: Double(progress.total))
                    .frame(maxWidth: 320)

                Text("Processed \(Format.count(progress.done)) of \(Format.count(progress.total))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}

private struct FolderResults: View {
    let result: ChecksumResult

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetadataStrip(
                path: result.metadata.root,
                detail:
                    "Computed \(Format.timestamp(result.metadata.computedAt)) · Format \(result.metadata.formatVersion) · Entries: \(Format.count(result.entries.count))"
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            AdaptiveContent {
                List(result.entries, id: \.path) { entry in
                    ChecksumRow(
                        name: result.relativePath(of: entry),
                        size: Format.size(entry.size),
                        checksum: Format.checksum(entry),
                        date: Format.day(entry.modified)
                    )
                    .copyRowMenu(ChecksumRowText.line(for: entry))
                }
                .listStyle(.plain)
            } wide: {
                ChecksumTable(result: result)
            }
        }
    }
}
