import SwiftUI

struct FolderSectionView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var model = app.folder

        NavigationStack(path: $model.path) {
            picker
                .navigationDestination(for: FolderSectionModel.Route.self) { _ in
                    FolderResultView(model: model)
                }
        }
        .fileImporter(
            isPresented: $model.isChoosingSource,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                return
            }

            model.folderChosen(url)
        }
        .onChange(of: model.path) { _, path in
            if path.isEmpty {
                model.returned()
            }
        }
    }

    private var picker: some View {
        Button("Checksum Folder…") {
            app.folder.chooseFolder()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HelpButton()
            }
        }
    }
}
