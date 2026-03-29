import Foundation

enum AppIconOption: String, CaseIterable {
    case `default` = "AppIcon"
    case icon1 = "AppIcon1"
    case icon2 = "AppIcon2"
    case icon3 = "AppIcon3"

    var displayName: String {
        switch self {
        case .default: return "Icon 4"
        case .icon1:   return "Icon 1"
        case .icon2:   return "Icon 2"
        case .icon3:   return "Icon 3"
        }
    }

    /// The name passed to `UIApplication.setAlternateIconName(_:)`.
    /// `nil` means reset to the primary icon.
    var alternateIconName: String? {
        self == .default ? nil : rawValue
    }
}
