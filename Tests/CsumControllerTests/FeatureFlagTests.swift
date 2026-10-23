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

    func testTheViewTabUsesItsDashboardNameAndDefaultsOn() {
        XCTAssertEqual(FeatureFlag.viewTab.rawValue, "view_tab")
        XCTAssertTrue(FeatureFlag.viewTab.isOnByDefault)
        XCTAssertTrue(FeatureFlagValues().isOn(.viewTab))
    }

    func testAnOffTreatmentHidesTheViewTab() {
        let values = FeatureFlagValues(treatments: [.viewTab: "off"])

        XCTAssertFalse(values.isOn(.viewTab))
    }
}
