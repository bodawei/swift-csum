import SwiftUI

struct ExportShareLink: View {
    let export: CsumExport?

    var body: some View {
        if let export {
            switch export.kind {
            case .checksums:
                ShareLink(item: export.csvFile, preview: SharePreview(export.fileName)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

            case .comparison:
                ShareLink(item: export.comparisonFile, preview: SharePreview(export.fileName)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
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
