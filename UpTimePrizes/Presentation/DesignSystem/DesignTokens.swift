import SwiftUI

// MARK: - Design Tokens

/// Central design system for UpTime Prizes.
/// Colors are defined in Assets.xcassets as named colors AND as SwiftUI Color extensions.
/// Typography uses Playfair Display (Regular and SemiBold).

// MARK: - Color tokens (SwiftUI extensions)

extension Color {
    /// Accent color — buttons, highlights, active states (#B5985A)
    static let brass = Color("brass")
    /// Background color — warm off-white (#F4F1EA)
    static let paper = Color("paper")
    /// Text color — deep warm brown (#2B1E12)
    static let ink = Color("ink")
}

// MARK: - Typography tokens

extension Font {
    static func playfair(size: CGFloat) -> Font {
        .custom("PlayfairDisplay-Regular", size: size)
    }

    static func playfairSemiBold(size: CGFloat) -> Font {
        .custom("PlayfairDisplay-SemiBold", size: size)
    }
}

// MARK: - Color asset values (for reference / UIKit usage)

struct DesignTokens {
    struct Colors {
        static let brass = UIColor(red: 0.710, green: 0.596, blue: 0.353, alpha: 1.0)
        static let paper = UIColor(red: 0.957, green: 0.945, blue: 0.918, alpha: 1.0)
        static let ink   = UIColor(red: 0.169, green: 0.118, blue: 0.071, alpha: 1.0)
    }
}
