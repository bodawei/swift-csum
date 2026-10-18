#if os(macOS)
import AppKit
import UniformTypeIdentifiers
import CsumController

enum FileDialogs {
    static func pickSources(
        selectFolders: Bool,
        algorithm: ChecksumAlgorithm,
        algorithmChanged: @escaping (ChecksumAlgorithm) -> Void,
        completion: @escaping ([URL]) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !selectFolders
        panel.canChooseDirectories = selectFolders
        panel.allowsMultipleSelection = true

        let algorithms = ChecksumAlgorithm.allCases
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: algorithms.map(\.displayName))
        popup.selectItem(at: max(0, algorithms.firstIndex(of: algorithm) ?? 0))

        let label = NSTextField(labelWithString: "Algorithm:")
        let accessory = NSStackView(views: [label, popup])
        accessory.frame = NSRect(x: 0, y: 0, width: accessory.fittingSize.width, height: 28)
        panel.accessoryView = accessory

        guard let window = keyWindow() else {
            return
        }

        panel.beginSheetModal(for: window) { [popup] response in
            guard response == .OK else {
                return
            }

            let index = max(0, min(popup.indexOfSelectedItem, algorithms.count - 1))

            algorithmChanged(algorithms[index])
            completion(panel.urls)
        }
    }

    static func pickCsv(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.message = "Choose a .csum.csv file"

        guard let window = keyWindow() else {
            completion(nil)

            return
        }

        panel.beginSheetModal(for: window) { response in
            completion(response == .OK ? panel.url : nil)
        }
    }

    static func pickFolder(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.message = "Choose a folder"

        guard let window = keyWindow() else {
            completion(nil)

            return
        }

        panel.beginSheetModal(for: window) { response in
            completion(response == .OK ? panel.url : nil)
        }
    }

    private static func keyWindow() -> NSWindow? {
        NSApplication.shared.mainWindow ?? NSApplication.shared.windows.first
    }
}
#endif
