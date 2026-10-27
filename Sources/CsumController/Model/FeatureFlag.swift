public enum FeatureFlag: String, CaseIterable, Sendable {
    case viewTab = "view_tab"

    public var isOnByDefault: Bool {
        switch self {
        case .viewTab:
            return true
        }
    }
}

public struct FeatureFlagValues: Sendable {
    private enum Treatment {
        static let on = "on"
        static let off = "off"
    }

    private let treatments: [FeatureFlag: String]

    public init(treatments: [FeatureFlag: String] = [:]) {
        self.treatments = treatments
    }

    public func isOn(_ flag: FeatureFlag) -> Bool {
        switch treatments[flag] {
        case Treatment.on:
            return true

        case Treatment.off:
            return false

        default:
            return flag.isOnByDefault
        }
    }
}
