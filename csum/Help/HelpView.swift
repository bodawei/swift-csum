import SwiftUI

struct HelpView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            List(HelpTopic.all) { topic in
                NavigationLink {
                    HelpTopicView(topic: topic) {
                        app.hideHelp()
                    }
                } label: {
                    Text(topic.title)
                        .font(.body.weight(.medium))
                }
                .accessibilityIdentifier("help-topic-\(topic.id)")
            }
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    HelpDoneButton {
                        app.hideHelp()
                    }
                }
            }
        }
    }
}

private struct HelpTopicView: View {
    let topic: HelpTopic
    let close: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, paragraph in
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
                HelpDoneButton(close: close)
            }
        }
    }
}

private struct HelpDoneButton: View {
    let close: () -> Void

    var body: some View {
        Button("Done", action: close)
            .accessibilityIdentifier("doneHelp")
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
