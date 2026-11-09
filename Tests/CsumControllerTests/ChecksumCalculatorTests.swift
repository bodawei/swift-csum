import XCTest

@testable import CsumController

final class ChecksumCalculatorTests: XCTestCase {
    private var tree: TempTree!

    override func setUpWithError() throws {
        tree = try TempTree()
    }

    override func tearDownWithError() throws {
        tree.remove()
        tree = nil
    }

    private func assertDigestsAtChunkBoundary(
        _ count: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let contents = Data((0..<count).map { UInt8($0 % 251) })
        let url = try tree.file("file-\(count).bin", contents: contents)

        for algorithm in ChecksumAlgorithm.allCases {
            XCTAssertEqual(
                try ChecksumCalculator.checksum(of: url, algorithm: algorithm),
                digest(of: contents, using: algorithm),
                "\(algorithm) at \(count) bytes",
                file: file,
                line: line
            )
        }
    }

    func testEmptyFile() throws {
        try assertDigestsAtChunkBoundary(0)
    }

    func testFileShorterThanOneChunk() throws {
        try assertDigestsAtChunkBoundary(ChecksumCalculator.chunkSize - 1)
    }

    func testFileOfExactlyOneChunk() throws {
        try assertDigestsAtChunkBoundary(ChecksumCalculator.chunkSize)
    }

    func testFileOfOneChunkAndOneByte() throws {
        try assertDigestsAtChunkBoundary(ChecksumCalculator.chunkSize + 1)
    }

    func testTwoChunksAndOneByte() throws {
        try assertDigestsAtChunkBoundary(ChecksumCalculator.chunkSize * 2 + 1)
    }

    func testUnreadableFileIsReportedAsCannotOpen() throws {
        try XCTSkipIf(getuid() == 0, "running as root, so permissions are not enforced")

        let url = try tree.file("secret.bin", contents: Data("secret".utf8))
        try tree.setPermissions(0o000, at: "secret.bin")
        defer {
            try? tree.setPermissions(0o600, at: "secret.bin")
        }

        XCTAssertThrowsError(try ChecksumCalculator.checksum(of: url, algorithm: .sha256)) {
            error in
            guard let error = error as? ChecksumError else {
                XCTFail("expected a ChecksumError, got \(error)")

                return
            }

            guard case .cannotOpen = error else {
                XCTFail("expected cannotOpen, got \(error)")

                return
            }
        }
    }
}
