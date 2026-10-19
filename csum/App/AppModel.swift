import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Section: String, CaseIterable, Hashable {
        case file
        case folder
        case compare
    }

    var selectedSection: Section = .file
    var isPresentingSaveAs = false

    let file: FileSectionModel
    let folder: FolderSectionModel
    let compare: CompareSectionModel

    init(demoMode: Bool = ProcessInfo.processInfo.arguments.contains("-csumUITestMode")) {
        #if DEBUG
            let service: any Checksumming = demoMode ? DemoService() : ControllerService()
        #else
            let service: any Checksumming = ControllerService()
        #endif

        file = FileSectionModel(service: service, demoMode: demoMode)
        folder = FolderSectionModel(service: service, demoMode: demoMode)
        compare = CompareSectionModel(service: service, demoMode: demoMode)

        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-csumUITestSaveAs") {
                file.fileChosen(DemoData.fileURL)
            }
        #endif
    }

    var currentExport: CsumCSVFile? {
        switch selectedSection {
        case .file:
            return file.export
        case .folder:
            return folder.export
        case .compare:
            return compare.export
        }
    }

    var canSaveAs: Bool {
        currentExport != nil
    }

    func saveAs() {
        guard canSaveAs else {
            return
        }

        isPresentingSaveAs = true
    }
}
