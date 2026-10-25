import CsumController
import Foundation
import PostHog

final class PostHogFeatureFlags: FeatureFlagProviding, @unchecked Sendable {
    private let startup: PostHogStartup

    private init(startup: PostHogStartup) {
        self.startup = startup
    }

    static func makeFromConfiguration(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PostHogFeatureFlags {
        let startup = PostHogStartup(bundle: bundle, environment: environment)
        startup.start()

        return PostHogFeatureFlags(startup: startup)
    }

    func evaluateTreatments() -> [FeatureFlag: String] {
        guard startup.hasStarted else {
            return [:]
        }

        var treatments = [FeatureFlag: String]()

        for flag in FeatureFlag.allCases {
            treatments[flag] = Self.treatment(from: PostHogSDK.shared.getFeatureFlag(flag.rawValue))
        }

        return treatments
    }

    func start(onChange: @escaping @Sendable () -> Void) {
        guard startup.hasStarted else {
            return
        }

        PostHogSDK.shared.onFeatureFlags { _ in onChange() }
        PostHogSDK.shared.reloadFeatureFlags()
    }

    static func treatment(from value: Any?) -> String? {
        switch value {
        case let enabled as Bool:
            return enabled ? "on" : "off"

        case let variant as String:
            return variant.isEmpty ? nil : variant

        default:
            return nil
        }
    }
}
