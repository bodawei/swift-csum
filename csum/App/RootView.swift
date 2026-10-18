import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        TabView(selection: $model.selectedSection) {
            FileSectionView()
                .tabItem {
                    Label("File", systemImage: "doc")
                }
                .tag(AppModel.Section.file)

            FolderSectionView()
                .tabItem {
                    Label("Folder", systemImage: "folder")
                }
                .tag(AppModel.Section.folder)

            CompareSectionView()
                .tabItem {
                    Label("Compare", systemImage: "doc.on.doc")
                }
                .tag(AppModel.Section.compare)
        }
    }
}
