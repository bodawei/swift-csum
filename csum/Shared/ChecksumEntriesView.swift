import CsumController
import SwiftUI

struct ChecksumEntriesView: View {
    private enum Layout {
        static let inset: CGFloat = 20
    }

    let result: ChecksumResult

    var body: some View {
        AdaptiveContent {
            list
        } wide: {
            ChecksumTable(result: result)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(result.entries, id: \.path) { entry in
                    ChecksumRow(
                        name: result.relativePath(of: entry),
                        size: Format.size(entry.size),
                        checksum: Format.checksum(entry),
                        date: Format.day(entry.modified)
                    )
                    .padding(.horizontal, Layout.inset)
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                    .copyRowMenu(ChecksumRowText.line(for: entry))
                }
            }
            .padding(.bottom, 12)
        }
    }
}
