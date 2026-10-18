import CsumController
import Foundation
import Observation

@MainActor
@Observable
final class FileSectionModel {
    enum Phase {
        case idle
        case running
        case loaded(ChecksumResult)
        case failed(String)
    }

    enum Route: Hashable {
        case result
    }

    typealias Sleeper = @Sendable (Duration) async throws -> Void

    private(set) var phase: Phase = .idle
    var path: [Route] = []
    var isChoosingSource = false
    private(set) var showsSpinner = false
    private(set) var export: CsumCSVFile?

    private let service: any Checksumming
    private let sleep: Sleeper
    private let demoMode: Bool
    private var task: Task<Void, Never>?

    init(
        service: any Checksumming = ControllerService(),
        sleep: @escaping Sleeper = { try await Task.sleep(for: $0) },
        demoMode: Bool = false
    ) {
        self.service = service
        self.sleep = sleep
        self.demoMode = demoMode
    }

    func chooseFile() {
        #if DEBUG
            if demoMode {
                fileChosen(DemoData.fileURL)
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
        showsSpinner = false
        export = nil
    }

    private func start(_ url: URL) {
        task?.cancel()
        phase = .running
        showsSpinner = false
        export = nil

        let spinner = Task { [weak self] in
            try? await self?.sleep(.milliseconds(500))

            guard !Task.isCancelled else {
                return
            }

            self?.showsSpinner = true
        }

        task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let result = try await service.checksum(at: url) { _, _ in }
                phase = .loaded(result)
                export = CsumCSVFile(
                    text: ChecksumFileCodec.render(result),
                    fileName: url.lastPathComponent + ".csum.csv"
                )
            } catch is CancellationError {
                spinner.cancel()
                showsSpinner = false

                return
            } catch {
                phase = .failed(error.localizedDescription)
            }

            spinner.cancel()
            showsSpinner = false
        }
    }
}
