import Foundation

enum AppIconOption: String, CaseIterable {
    case `default` = "AppIcon"
    case icon2 = "AppIcon2"
    case icon3 = "AppIcon3"
    case icon4 = "AppIcon4"

    var displayName: String {
        switch self {
        case .default: return "Icon 1"
        case .icon2:   return "Icon 2"
        case .icon3:   return "Icon 3"
        case .icon4:   return "Icon 4"
        }
    }

    /// The name passed to `UIApplication.setAlternateIconName(_:)`.
    /// `nil` means reset to the primary icon.
    var alternateIconName: String? {
        self == .default ? nil : rawValue
    }
}
