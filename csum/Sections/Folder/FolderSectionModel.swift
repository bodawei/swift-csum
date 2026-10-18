import CsumController
import Foundation
import Observation

@MainActor
@Observable
final class FolderSectionModel {
    enum Phase {
        case idle
        case running
        case loaded(ChecksumResult)
        case failed(String)
    }

    enum Route: Hashable {
        case result
    }

    private final class ProgressThrottle: @unchecked Sendable {
        private let lock = NSLock()
        private var lastPercent = -1

        func shouldReport(done: Int, total: Int) -> Bool {
            lock.lock()
            defer {
                lock.unlock()
            }

            let percent = total > 0 ? done * 100 / total : 0

            guard percent != lastPercent || done == total else {
                return false
            }

            lastPercent = percent

            return true
        }
    }

    private(set) var phase: Phase = .idle
    var path: [Route] = []
    var isChoosingSource = false
    private(set) var progress: (done: Int, total: Int)?
    private(set) var export: CsumCSVFile?

    private let service: any Checksumming
    private let demoMode: Bool
    private var task: Task<Void, Never>?

    init(service: any Checksumming = ControllerService(), demoMode: Bool = false) {
        self.service = service
        self.demoMode = demoMode
    }

    func chooseFolder() {
        #if DEBUG
            if demoMode {
                folderChosen(DemoData.folderURL)
                return
            }
        #endif

        isChoosingSource = true
    }

    func folderChosen(_ url: URL) {
        path = [.result]
        start(url)
    }

    func returned() {
        task?.cancel()
        task = nil
        phase = .idle
        progress = nil
        export = nil
    }

    private func start(_ url: URL) {
        task?.cancel()
        phase = .running
        progress = nil
        export = nil

        let throttle = ProgressThrottle()

        task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let result = try await service.checksum(at: url) { [weak self] done, total in
                    guard throttle.shouldReport(done: done, total: total) else {
                        return
                    }

                    Task { @MainActor in
                        self?.progress = (done, total)
                    }
                }

                phase = .loaded(result)
                progress = nil
                export = CsumCSVFile(
                    text: ChecksumFileCodec.render(result),
                    fileName: url.lastPathComponent + ".csum.csv"
                )
            } catch is CancellationError {
                return
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
