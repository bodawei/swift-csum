import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    enum Section: String, CaseIterable, Hashable {
        case file
        case folder
        case view
        case compare
    }

    var selectedSection: Section = .file
    var isPresentingSaveAs = false
    var isPresentingHelp = false

    let file: FileSectionModel
    let folder: FolderSectionModel
    let csum: CsumSectionModel
    let compare: CompareSectionModel
    let featureFlags: FeatureFlagStore

    init(
        demoMode: Bool = ProcessInfo.processInfo.arguments.contains("-csumUITestMode"),
        featureFlags: FeatureFlagStore? = nil
    ) {
        #if DEBUG
            let service: any Checksumming = demoMode ? DemoService() : ControllerService()
        #else
            let service: any Checksumming = ControllerService()
        #endif

        let featureFlags = featureFlags ?? FeatureFlagStore()
        self.featureFlags = featureFlags
        featureFlags.start()

        file = FileSectionModel(service: service, demoMode: demoMode)
        folder = FolderSectionModel(service: service, demoMode: demoMode)
        csum = CsumSectionModel(service: service, demoMode: demoMode)
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
        case .view:
            return csum.export
        case .compare:
            return compare.export
        }
    }

    var showsViewTab: Bool {
        featureFlags.isOn(.viewTab)
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

    func showHelp() {
        isPresentingHelp = true
    }
}
