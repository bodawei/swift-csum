import XCTest

@testable import CsumController

final class FeatureFlagTests: XCTestCase {
    func testAFlagWithNoTreatmentUsesItsDefault() {
        XCTAssertTrue(FeatureFlag.copyChecksum.isOnByDefault)
        XCTAssertTrue(FeatureFlagValues().isOn(.copyChecksum))
    }

    func testAnOnTreatmentTurnsAFlagOn() {
        let values = FeatureFlagValues(treatments: [.copyChecksum: "on"])

        XCTAssertTrue(values.isOn(.copyChecksum))
    }

    func testAnOffTreatmentTurnsAFlagOff() {
        let values = FeatureFlagValues(treatments: [.copyChecksum: "off"])

        XCTAssertFalse(values.isOn(.copyChecksum))
    }

    func testAnUnknownTreatmentUsesTheDefault() {
        let values = FeatureFlagValues(treatments: [.copyChecksum: "control"])

        XCTAssertTrue(values.isOn(.copyChecksum))
    }
}
