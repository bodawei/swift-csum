import SwiftUI

struct FileSectionView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Checksum a File", systemImage: "doc")
        } description: {
            Text("Choose a single file to checksum.")
        }
    }
}
