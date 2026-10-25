import Foundation
import PostHog

final class PostHogStartup {
    private let configuration: PostHogConfiguration?
    private var isStarted = false

    init(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        configuration = PostHogConfiguration.from(bundle: bundle, environment: environment)
    }

    var hasStarted: Bool {
        isStarted
    }

    func start() {
        guard !isStarted, let configuration else {
            return
        }

        let config = PostHogConfig(
            projectToken: configuration.projectToken, host: configuration.host)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.captureElementInteractions = false
        config.sendFeatureFlagEvent = false

        PostHogSDK.shared.setup(config)

        isStarted = true
    }

    func stop() {
        guard isStarted else {
            return
        }

        PostHogSDK.shared.close()

        isStarted = false
    }
}
