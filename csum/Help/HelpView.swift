import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(HelpTopic.all) { topic in
                NavigationLink {
                    HelpTopicView(topic: topic)
                } label: {
                    Text(topic.title)
                        .font(.body.weight(.medium))
                }
                .accessibilityIdentifier("help-topic-\(topic.id)")
            }
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("doneHelp")
                }
            }
        }
    }
}

private struct HelpTopicView: View {
    @Environment(\.dismiss) private var dismiss

    let topic: HelpTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(topic.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(topic.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .accessibilityIdentifier("doneHelp")
            }
        }
    }
}

struct HelpButton: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Button {
            app.showHelp()
        } label: {
            Label("Help", systemImage: "questionmark.circle")
        }
        .accessibilityIdentifier("help")
    }
}
