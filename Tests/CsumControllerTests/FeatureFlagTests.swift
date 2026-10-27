import XCTest

@testable import CsumController

final class FeatureFlagTests: XCTestCase {
    func testAFlagWithNoTreatmentUsesItsDefault() {
        XCTAssertTrue(FeatureFlag.viewTab.isOnByDefault)
        XCTAssertTrue(FeatureFlagValues().isOn(.viewTab))
    }

    func testAnOnTreatmentTurnsAFlagOn() {
        let values = FeatureFlagValues(treatments: [.viewTab: "on"])

        XCTAssertTrue(values.isOn(.viewTab))
    }

    func testAnOffTreatmentTurnsAFlagOff() {
        let values = FeatureFlagValues(treatments: [.viewTab: "off"])

        XCTAssertFalse(values.isOn(.viewTab))
    }

    func testAnUnknownTreatmentUsesTheDefault() {
        let values = FeatureFlagValues(treatments: [.viewTab: "control"])

        XCTAssertTrue(values.isOn(.viewTab))
    }

    func testTheViewTabUsesItsDashboardName() {
        XCTAssertEqual(FeatureFlag.viewTab.rawValue, "view_tab")
    }
}
