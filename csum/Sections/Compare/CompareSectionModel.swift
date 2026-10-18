import CsumController
import Foundation
import Observation

@MainActor
@Observable
final class CompareSectionModel {
    enum Kind: String, CaseIterable, Hashable {
        case csumFile
        case folder
    }

    enum Phase {
        case idle
        case running
        case loaded(ChecksumComparison)
        case failed(String)
    }

    enum Route: Hashable {
        case result
    }

    private(set) var first: URL?
    private(set) var second: URL?
    private(set) var firstKind: Kind = .csumFile
    private(set) var secondKind: Kind = .csumFile
    var isChoosingFirst = false
    var isChoosingSecond = false
    var path: [Route] = []
    private(set) var phase: Phase = .idle
    private(set) var export: CsumCSVFile?

    private let service: any Checksumming
    private let demoMode: Bool
    private var task: Task<Void, Never>?

    init(service: any Checksumming = ControllerService(), demoMode: Bool = false) {
        self.service = service
        self.demoMode = demoMode

        #if DEBUG
            if demoMode {
                firstKind = .folder
                secondKind = .folder
            }
        #endif
    }

    var isRunning: Bool {
        if case .running = phase {
            return true
        }

        return false
    }

    var canCompare: Bool {
        first != nil && second != nil && !isRunning
    }

    func setFirstKind(_ kind: Kind) {
        firstKind = kind
        first = nil
    }

    func setSecondKind(_ kind: Kind) {
        secondKind = kind
        second = nil
    }

    func chooseFirst() {
        #if DEBUG
            if demoMode {
                setFirst(DemoData.folderURL)
                return
            }
        #endif

        isChoosingFirst = true
    }

    func chooseSecond() {
        #if DEBUG
            if demoMode {
                setSecond(DemoData.copiedFolderURL)
                return
            }
        #endif

        isChoosingSecond = true
    }

    func setFirst(_ url: URL) {
        first = url
    }

    func setSecond(_ url: URL) {
        second = url
    }

    func swap() {
        let url = first
        first = second
        second = url

        let kind = firstKind
        firstKind = secondKind
        secondKind = kind
    }

    func compareTapped() {
        guard let first, let second, !isRunning else {
            return
        }

        path = [.result]
        start(first: first, second: second)
    }

    func returned() {
        task?.cancel()
        task = nil
        phase = .idle
        export = nil
    }

    private func start(first: URL, second: URL) {
        task?.cancel()
        phase = .running
        export = nil

        task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let comparison = try await service.compare(first: first, second: second)
                phase = .loaded(comparison)
                export = CsumCSVFile(
                    text: ComparisonFileCodec.render(comparison),
                    fileName: "Comparison.csum.csv"
                )
            } catch is CancellationError {
                return
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
