import SwiftUI
import UniformTypeIdentifiers

struct CsumSectionView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var model = app.csum

        NavigationStack(path: $model.path) {
            picker
                .navigationDestination(for: CsumSectionModel.Route.self) { _ in
                    CsumResultView(model: model)
                }
        }
        .fileImporter(
            isPresented: $model.isChoosingSource,
            allowedContentTypes: [.commaSeparatedText],
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
        Button("Open .csum.csv…") {
            app.csum.chooseFile()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(.hidden, for: .navigationBar)
    }
}
