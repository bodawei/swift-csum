import SwiftUI

struct CompareFormView: View {
    @Binding var sources: [CompareSource?]
    let isBusy: Bool
    let onPickCsv: (Int) -> Void
    let onPickFolder: (Int) -> Void
    let onCompare: () -> Void

    @State private var csvTargeted = [false, false]
    @State private var folderTargeted = [false, false]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(0)
            row(1)
            Button("Compare") {
                onCompare()
            }
            .buttonStyle(.bordered)
            .disabled(sources[0] == nil || sources[1] == nil || isBusy)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func row(_ index: Int) -> some View {
        HStack(spacing: 10) {
            Button("Choose .csum.csv") {
                onPickCsv(index)
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first, url.path.lowercased().hasSuffix(".csum.csv") else {
                    return false
                }
                sources[index] = CompareSource(
                    name: url.lastPathComponent,
                    path: url.path,
                    url: url,
                    isFolder: false
                )
                return true
            } isTargeted: {
                csvTargeted[index] = $0
            }
            .dropHighlight(csvTargeted[index])

            Button("Choose Folder") {
                onPickFolder(index)
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else {
                    return false
                }
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                sources[index] = CompareSource(
                    name: url.lastPathComponent,
                    path: url.path,
                    url: url,
                    isFolder: isDirectory
                )
                return true
            } isTargeted: {
                folderTargeted[index] = $0
            }
            .dropHighlight(folderTargeted[index])

            if let source = sources[index] {
                Text(source.summary)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer()
        }
    }
}
