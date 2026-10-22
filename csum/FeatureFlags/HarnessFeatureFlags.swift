import CsumController
import Foundation
import Split

final class HarnessFeatureFlags: FeatureFlagProviding, @unchecked Sendable {
    private static let apiKeyName = "HARNESS_FME_CLIENT_KEY"
    private static let installationIDKey = "com.djb.csum.installationID"

    private let factory: SplitFactory?

    private init(factory: SplitFactory?) {
        self.factory = factory
    }

    static func makeFromConfiguration(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> HarnessFeatureFlags {
        guard let apiKey = configuredAPIKey(bundle: bundle, environment: environment) else {
            return HarnessFeatureFlags(factory: nil)
        }

        let config = SplitClientConfig()
        config.logLevel = .error

        let factory = DefaultSplitFactoryBuilder()
            .setApiKey(apiKey)
            .setKey(Key(matchingKey: installationID()))
            .setConfig(config)
            .build()

        return HarnessFeatureFlags(factory: factory)
    }

    func evaluateTreatments() -> [FeatureFlag: String] {
        guard let client = factory?.client else {
            return [:]
        }

        var treatments = [FeatureFlag: String]()

        for flag in FeatureFlag.allCases {
            treatments[flag] = client.getTreatment(flag.rawValue)
        }

        return treatments
    }

    func start(onChange: @escaping @Sendable () -> Void) {
        guard let client = factory?.client else {
            return
        }

        client.on(event: .sdkReady) { onChange() }
        client.on(event: .sdkReadyFromCache) { onChange() }
        client.on(event: .sdkUpdated) { onChange() }
    }

    private static func configuredAPIKey(
        bundle: Bundle,
        environment: [String: String]
    ) -> String? {
        let configured =
            environment[apiKeyName]
            ?? bundle.object(forInfoDictionaryKey: apiKeyName) as? String

        guard let configured, !configured.isEmpty else {
            return nil
        }

        return configured
    }

    private static func installationID(defaults: UserDefaults = .standard) -> String {
        if let installationID = defaults.string(forKey: installationIDKey) {
            return installationID
        }

        let installationID = UUID().uuidString
        defaults.set(installationID, forKey: installationIDKey)

        return installationID
    }
}
