import XCTest
@testable import CsumController

final class ChecksumAlgorithmTests: XCTestCase {
    func testAllAlgorithmsArePresent() {
        XCTAssertEqual(ChecksumAlgorithm.allCases.count, 3)
    }

    func testDisplayNames() {
        XCTAssertEqual(ChecksumAlgorithm.sha256.displayName, "SHA-256")
        XCTAssertEqual(ChecksumAlgorithm.sha1.displayName, "SHA-1")
        XCTAssertEqual(ChecksumAlgorithm.md5.displayName, "MD5")
    }

    func testRawValues() {
        XCTAssertEqual(ChecksumAlgorithm.sha256.rawValue, "sha256")
        XCTAssertEqual(ChecksumAlgorithm.sha1.rawValue, "sha1")
        XCTAssertEqual(ChecksumAlgorithm.md5.rawValue, "md5")
    }
}
