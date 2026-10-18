import XCTest

@testable import CsumController

final class CancellationTests: XCTestCase {
    private final class Calls: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        func next() -> Int {
            lock.lock()
            defer {
                lock.unlock()
            }

            count += 1

            return count
        }
    }

    private var tree: TempTree!

    override func setUpWithError() throws {
        tree = try TempTree()

        for index in 0..<6 {
            try tree.text("file-\(index).txt", "contents \(index)")
        }
    }

    override func tearDown() {
        tree.remove()
        tree = nil
    }

    func testAFolderRunStopsWhenTheHookReportsCancellation() {
        let controller = CsumController(algorithm: .sha256, writer: "tests")
        let calls = Calls()

        XCTAssertThrowsError(
            try controller.calculateChecksums(at: tree.url, isCancelled: { calls.next() > 2 })
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testASingleFileRunStopsWhenTheHookReportsCancellation() throws {
        let file = tree.url.appendingPathComponent("file-0.txt")
        let controller = CsumController(algorithm: .sha256, writer: "tests")

        XCTAssertThrowsError(
            try controller.calculateChecksums(at: file, isCancelled: { true })
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testAComparisonStopsWhenTheHookReportsCancellation() throws {
        let other = try TempTree()

        defer {
            other.remove()
        }

        try other.text("file-0.txt", "contents 0")

        let controller = CsumController(algorithm: .sha256, writer: "tests")

        XCTAssertThrowsError(
            try controller.compare(first: tree.url, second: other.url, isCancelled: { true })
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    func testARunWithoutACancellationHookCompletes() throws {
        let controller = CsumController(algorithm: .sha256, writer: "tests")
        let result = try controller.calculateChecksums(at: tree.url)

        XCTAssertEqual(result.entries.count, 6)
    }
}
