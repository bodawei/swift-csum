import CsumController
import XCTest

@testable import csum

@MainActor
final class FeatureFlagStoreTests: XCTestCase {
    private final class StubFeatureFlags: FeatureFlagProviding, @unchecked Sendable {
        var treatments: [FeatureFlag: String] = [:]

        private var onChange: (@Sendable () -> Void)?

        func evaluateTreatments() -> [FeatureFlag: String] {
            treatments
        }

        func start(onChange: @escaping @Sendable () -> Void) {
            self.onChange = onChange
        }

        func change() {
            onChange?()
        }
    }

    func testAFlagWithNoTreatmentFallsBackToItsDefault() {
        let store = FeatureFlagStore(provider: StubFeatureFlags())

        store.start()

        XCTAssertTrue(store.isOn(.copyChecksum))
    }

    func testAnOffTreatmentHidesAFlag() {
        let flags = StubFeatureFlags()
        flags.treatments[.copyChecksum] = "off"
        let store = FeatureFlagStore(provider: flags)

        store.start()

        XCTAssertFalse(store.isOn(.copyChecksum))
    }

    func testAChangeNotificationRefreshesTheFlags() async {
        let flags = StubFeatureFlags()
        let store = FeatureFlagStore(provider: flags)

        store.start()

        XCTAssertTrue(store.isOn(.copyChecksum))

        flags.treatments[.copyChecksum] = "off"
        flags.change()

        await waitUntil {
            !store.isOn(.copyChecksum)
        }

        XCTAssertFalse(store.isOn(.copyChecksum))
    }

    func testTheViewTabShowsWithoutATreatment() {
        let model = AppModel(featureFlags: FeatureFlagStore(provider: StubFeatureFlags()))

        XCTAssertTrue(model.showsViewTab)
    }

    func testTheViewTabCanBeTurnedOff() {
        let flags = StubFeatureFlags()
        flags.treatments[.viewTab] = "off"

        let model = AppModel(featureFlags: FeatureFlagStore(provider: flags))

        XCTAssertFalse(model.showsViewTab)
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition() && Date() < deadline {
            await Task.yield()
        }
    }
}
