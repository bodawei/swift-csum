import SwiftUI
import UniformTypeIdentifiers

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

            if model.showsViewTab {
                CsumSectionView()
                    .tabItem {
                        Label("View", systemImage: "tablecells")
                    }
                    .tag(AppModel.Section.view)
            }

            CompareSectionView()
                .tabItem {
                    Label("Compare", systemImage: "doc.on.doc")
                }
                .tag(AppModel.Section.compare)
        }
        .onChange(of: model.showsViewTab) { _, shows in
            if !shows, model.selectedSection == .view {
                model.selectedSection = .file
            }
        }
        .fileExporter(
            isPresented: $model.isPresentingSaveAs,
            document: CsumTextDocument(text: model.currentExport?.text ?? ""),
            contentType: model.currentExport?.contentType ?? .csumChecksums,
            defaultFilename: model.currentExport?.fileName
        ) { _ in }
        .sheet(isPresented: $model.isPresentingHelp) {
            HelpView()
        }
        #if targetEnvironment(macCatalyst)
            .background(WindowTitleHider())
        #endif
    }
}
