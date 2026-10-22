import CsumController
import Foundation
import Observation

@MainActor
@Observable
final class CsumSectionModel {
    enum Phase {
        case idle
        case running
        case loaded(ChecksumResult)
        case failed(String)
    }

    enum Route: Hashable {
        case result
    }

    private(set) var phase: Phase = .idle
    var path: [Route] = []
    var isChoosingSource = false
    private(set) var export: CsumCSVFile?

    private let service: any Checksumming
    private let demoMode: Bool
    private var task: Task<Void, Never>?

    init(service: any Checksumming = ControllerService(), demoMode: Bool = false) {
        self.service = service
        self.demoMode = demoMode
    }

    func chooseFile() {
        #if DEBUG
            if demoMode {
                fileChosen(DemoData.savedCsumFileURL)
                return
            }
        #endif

        isChoosingSource = true
    }

    func fileChosen(_ url: URL) {
        path = [.result]
        start(url)
    }

    func returned() {
        task?.cancel()
        task = nil
        phase = .idle
        export = nil
    }

    private func start(_ url: URL) {
        task?.cancel()
        phase = .running
        export = nil

        task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let result = try await service.readChecksumFile(at: url)
                phase = .loaded(result)
                export = CsumCSVFile(
                    text: ChecksumFileCodec.render(result),
                    fileName: url.lastPathComponent
                )
            } catch is CancellationError {
                return
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
