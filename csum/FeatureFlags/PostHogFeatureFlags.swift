import CsumController
import Foundation
import PostHog

struct PostHogConfiguration: Sendable {
    static let projectTokenKey = "POSTHOG_PROJECT_TOKEN"
    static let hostKey = "POSTHOG_HOST"
    static let defaultHost = "https://us.i.posthog.com"

    let projectToken: String
    let host: String

    static func from(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PostHogConfiguration? {
        guard
            let projectToken = value(for: projectTokenKey, bundle: bundle, environment: environment)
        else {
            return nil
        }

        let host = value(for: hostKey, bundle: bundle, environment: environment) ?? defaultHost

        return PostHogConfiguration(projectToken: projectToken, host: host)
    }

    var tracesEndpoint: URL? {
        guard var components = URLComponents(string: host) else {
            return nil
        }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        components.path = path.isEmpty ? "/i/v1/traces" : "/\(path)/i/v1/traces"

        return components.url
    }

    var tracesHeaders: [(String, String)] {
        [("Authorization", "Bearer \(projectToken)")]
    }

    private static func value(
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

final class PostHogFeatureFlags: FeatureFlagProviding, @unchecked Sendable {
    private let isConfigured: Bool

    private init(isConfigured: Bool) {
        self.isConfigured = isConfigured
    }

    static func makeFromConfiguration(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PostHogFeatureFlags {
        guard
            let configuration = PostHogConfiguration.from(bundle: bundle, environment: environment)
        else {
            return PostHogFeatureFlags(isConfigured: false)
        }

        let config = PostHogConfig(
            projectToken: configuration.projectToken, host: configuration.host)
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
}
