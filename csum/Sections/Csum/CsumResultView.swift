import CsumController
import SwiftUI

struct CsumResultView: View {
    let model: CsumSectionModel

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
            ProgressView()
                .controlSize(.large)
        case .loaded(let result):
            CsumFileContents(result: result)
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

private struct CsumFileContents: View {
    let result: ChecksumResult

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MetadataStrip(
                path: result.metadata.root,
                detail:
                    "Computed \(Format.timestamp(result.metadata.computedAt)) · \(result.metadata.algorithm.displayName) · Entries: \(Format.count(result.entries.count))"
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
