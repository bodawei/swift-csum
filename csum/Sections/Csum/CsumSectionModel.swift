import CsumController
import Foundation
import Observation
import PostHog

@MainActor
@Observable
final class CsumSectionModel {
    enum Phase {
        case idle
        case running
        case loaded(ChecksumResult)
        case loadedTable(CsvTable)
        case failed(String)
    }

    enum Route: Hashable {
        case result
    }

    private(set) var phase: Phase = .idle
    var path: [Route] = []
    var isChoosingSource = false
    private(set) var fileName: String?
    private(set) var export: CsumExport?

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
                let compares = ProcessInfo.processInfo.arguments.contains("-csumUITestCompareFile")
                fileChosen(compares ? DemoData.savedComparisonFileURL : DemoData.savedCsumFileURL)
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
        fileName = nil
        export = nil
    }

    private func start(_ url: URL) {
        task?.cancel()
        phase = .running
        fileName = url.lastPathComponent
        export = nil

        task = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let contents = try await service.readFile(at: url)
                load(contents, from: url)
            } catch is CancellationError {
                return
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func load(_ contents: CsumFileContents, from url: URL) {
        switch contents {
        case .checksums(let result):
            PostHogSDK.shared.capture(
                "checksum_file_viewed",
                properties: ["entry_count": result.entries.count]
            )
            phase = .loaded(result)
            export = CsumExport(
                text: ChecksumFileCodec.render(result),
                fileName: url.lastPathComponent,
                kind: .checksums
            )

        case .table(let table):
            phase = .loadedTable(table)
            export = CsumExport(
                text: table.text,
                fileName: url.lastPathComponent,
                kind: .comparison
            )
        }
    }
}
