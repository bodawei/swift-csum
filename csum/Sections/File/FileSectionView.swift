import SwiftUI

struct FileSectionView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var model = app.file

        NavigationStack(path: $model.path) {
            picker
                .navigationDestination(for: FileSectionModel.Route.self) { _ in
                    FileResultView(model: model)
                }
        }
        .fileImporter(
            isPresented: $model.isChoosingSource,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                return
            }

            model.fileChosen(url)
        }
        .onChange(of: model.path) { _, path in
            if path.isEmpty {
                model.returned()
            }
        }
    }

    private var picker: some View {
        Button("Checksum File…") {
            app.file.chooseFile()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
    }
}
