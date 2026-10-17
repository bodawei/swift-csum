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

    let file = FileSectionModel()
    let folder = FolderSectionModel()
    let compare = CompareSectionModel()
}
