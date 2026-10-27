import CsumController
import SwiftUI
import UniformTypeIdentifiers

struct CompareSectionView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var model = app.compare

        NavigationStack(path: $model.path) {
            picker
                .navigationDestination(for: CompareSectionModel.Route.self) { _ in
                    CompareResultView(model: model)
                }
        }
        .fileImporter(
            isPresented: $model.isChoosingFirst,
            allowedContentTypes: contentTypes(for: model.firstKind),
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                return
            }

            model.setFirst(url)
        }
        .fileImporter(
            isPresented: $model.isChoosingSecond,
            allowedContentTypes: contentTypes(for: model.secondKind),
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                return
            }

            model.setSecond(url)
        }
        .onChange(of: model.path) { _, path in
            if path.isEmpty {
                model.returned()
            }
        }
    }

    private var picker: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 14) {
                    source(
                        label: "First:",
                        kind: Binding(
                            get: { app.compare.firstKind },
                            set: { app.compare.setFirstKind($0) }
                        ),
                        url: app.compare.first,
                        chooseIdentifier: "chooseFirst"
                    ) {
                        app.compare.chooseFirst()
                    }

                    Divider()

                    source(
                        label: "Second:",
                        kind: Binding(
                            get: { app.compare.secondKind },
                            set: { app.compare.setSecondKind($0) }
                        ),
                        url: app.compare.second,
                        chooseIdentifier: "chooseSecond"
                    ) {
                        app.compare.chooseSecond()
                    }
                }
                .padding(16)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                Button("Swap") {
                    app.compare.swap()
                }
                .disabled(app.compare.first == nil && app.compare.second == nil)

                Button("Compare") {
                    app.compare.compareTapped()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("compareButton")
                .disabled(!app.compare.canCompare)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HelpButton()
            }
        }
    }

    private func source(
        label: LocalizedStringKey,
        kind: Binding<CompareSectionModel.Kind>,
        url: URL?,
        chooseIdentifier: String,
        choose: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let url {
                    Text(verbatim: displayPath(for: url))
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .help(displayPath(for: url))
                        .accessibilityIdentifier("\(chooseIdentifier)Path")
                } else {
                    Text("Nothing chosen yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                Picker("Source Type", selection: kind) {
                    Text(verbatim: ".csum.csv")
                        .tag(CompareSectionModel.Kind.csumFile)
                    Text("Folder")
                        .tag(CompareSectionModel.Kind.folder)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)

                Button("Choose…", action: choose)
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .accessibilityIdentifier(chooseIdentifier)

                Spacer()
            }
        }
    }

    private func displayPath(for url: URL) -> String {
        let path = url.path(percentEncoded: false)

        guard path.count > 1, path.hasSuffix("/") else {
            return path
        }

        return String(path.dropLast())
    }

    private func contentTypes(for kind: CompareSectionModel.Kind) -> [UTType] {
        switch kind {
        case .csumFile:
            return [.commaSeparatedText]
        case .folder:
            return [.folder]
        }
    }
}
