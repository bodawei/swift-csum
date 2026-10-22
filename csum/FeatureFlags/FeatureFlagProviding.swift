import CsumController

protocol FeatureFlagProviding: Sendable {
    func evaluateTreatments() -> [FeatureFlag: String]
    func start(onChange: @escaping @Sendable () -> Void)
}
