import CsumController
import Foundation
import PostHog

final class PostHogFeatureFlags: FeatureFlagProviding, @unchecked Sendable {
    private static let projectTokenKey = "POSTHOG_PROJECT_TOKEN"
    private static let hostKey = "POSTHOG_HOST"
    private static let defaultHost = "https://us.i.posthog.com"

    private let isConfigured: Bool

    private init(isConfigured: Bool) {
        self.isConfigured = isConfigured
    }

    static func makeFromConfiguration(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PostHogFeatureFlags {
        guard
            let projectToken = configuredValue(
                for: projectTokenKey, bundle: bundle, environment: environment)
        else {
            return PostHogFeatureFlags(isConfigured: false)
        }

        let host =
            configuredValue(for: hostKey, bundle: bundle, environment: environment) ?? defaultHost

        let config = PostHogConfig(projectToken: projectToken, host: host)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.captureElementInteractions = false

        PostHogSDK.shared.setup(config)

        return PostHogFeatureFlags(isConfigured: true)
    }

    func evaluateTreatments() -> [FeatureFlag: String] {
        guard isConfigured else {
            return [:]
        }

        var treatments = [FeatureFlag: String]()

        for flag in FeatureFlag.allCases {
            treatments[flag] = Self.treatment(from: PostHogSDK.shared.getFeatureFlag(flag.rawValue))
        }

        return treatments
    }

    func start(onChange: @escaping @Sendable () -> Void) {
        guard isConfigured else {
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

    private static func configuredValue(
        for key: String,
        bundle: Bundle,
        environment: [String: String]
    ) -> String? {
        let configured =
            environment[key]
            ?? bundle.object(forInfoDictionaryKey: key) as? String

        guard let configured, !configured.isEmpty else {
            return nil
        }

        return configured
    }
}
