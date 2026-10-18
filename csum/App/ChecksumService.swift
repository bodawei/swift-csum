import CsumController
import Foundation

protocol Checksumming: Sendable {
    func checksum(
        at url: URL,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> ChecksumResult

    func compare(first: URL, second: URL) async throws -> ChecksumComparison
}

struct ControllerService: Checksumming {
    var algorithm: ChecksumAlgorithm = .sha256
    var writer = CsumController.appWriter

    func checksum(
        at url: URL,
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async throws -> ChecksumResult {
        let controller = CsumController(algorithm: algorithm, writer: writer)

        return try await run {
            try controller.calculateChecksums(
                at: url,
                progress: progress,
                isCancelled: { Task.isCancelled }
            )
        }
    }

    func compare(first: URL, second: URL) async throws -> ChecksumComparison {
        let controller = CsumController(algorithm: algorithm, writer: writer)

        return try await run {
            try controller.compare(
                first: first,
                second: second,
                isCancelled: { Task.isCancelled }
            )
        }
    }

    private func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        let task = Task.detached(priority: .userInitiated) {
            try work()
        }

        return try await withTaskCancellationHandler(
            operation: {
                try await task.value
            },
            onCancel: {
                task.cancel()
            }
        )
    }
}
