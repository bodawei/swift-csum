import CsumController
import Observation

@MainActor
@Observable
final class FeatureFlagStore {
    private(set) var values = FeatureFlagValues()

    private let provider: any FeatureFlagProviding

    init(provider: any FeatureFlagProviding = PostHogFeatureFlags.makeFromConfiguration()) {
        self.provider = provider
    }

    func isOn(_ flag: FeatureFlag) -> Bool {
        values.isOn(flag)
    }

    func start() {
        refresh()

        provider.start { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func refresh() {
        values = FeatureFlagValues(treatments: provider.evaluateTreatments())
    }
}
