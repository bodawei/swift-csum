import Foundation

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
