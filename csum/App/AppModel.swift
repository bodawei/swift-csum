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
    }
}
