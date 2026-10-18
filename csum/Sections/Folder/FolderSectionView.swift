import SwiftUI

struct FolderSectionView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Checksum a Folder", systemImage: "folder")
        } description: {
            Text("Choose a folder to checksum.")
        }
    }
}
