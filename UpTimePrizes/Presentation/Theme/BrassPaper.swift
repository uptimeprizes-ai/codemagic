import SwiftUI

// MARK: - Brass & Paper
//
// The "Classic Brass & Paper" theme, token for token from the shipping
// Android app (AppTheme.BrassAndPaper). Values are 0xAARRGGBB, exactly as
// Android writes them, so the two apps can be compared line by line.

extension Color {
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}

enum BrassPaper {
    static let gradientTop = Color(argb: 0xFFD4C28F)
    static let gradientBot = Color(argb: 0xFFC8B47E)
    static let grain = Color(argb: 0xFF5F4E32)

    static let ink = Color(argb: 0xFF2B1E12)
    static let inkSoft = Color(argb: 0xFF5A4631)

    static let brass1 = Color(argb: 0xFF8A6D3D)
    static let brass2 = Color(argb: 0xFFC6A970)
    static let brass3 = Color(argb: 0xFF6A4F28)
    static let brassHighlight = Color(argb: 0xFFE9D4A6)
    static let brassDeep = Color(argb: 0xFF4E3818)

    static let screenGlow = Color(argb: 0xFFEADFBC)

    static let clockFaceBg = Color(argb: 0xFFFFFDF8)
    static let clockFaceWarm = Color(argb: 0xFFF5EDD0)
    static let clockBorder = Color(argb: 0xFF342818)
    static let clockNumeral = Color(argb: 0xFF17120D)
    static let handDark = Color(argb: 0xFF554331)
    static let handLight = Color(argb: 0xFF8F7B63)
    static let handMinDark = Color(argb: 0xFF44311F)
    static let handMinLight = Color(argb: 0xFF76644C)
    static let handSecRust = Color(argb: 0xFFA84A2D)
    static let numeralEngrave = Color(argb: 0xCCFFF6E0)
    static let centerCapLight = Color(argb: 0xFFD6C2A1)
    static let centerCapMid = Color(argb: 0xFFB49869)
    static let centerCapDark = Color(argb: 0xFF6E5630)
    static let centerCapEdge = Color(argb: 0xFF4C3821)
    static let clockText = Color(argb: 0xFF352614)

    static let screwLight = Color(argb: 0xFFE2D0A8)
    static let screwDark = Color(argb: 0xFF5E4522)

    static let eyebrow = Color(argb: 0xFF7B6545)

    static let plaqueTop = Color(argb: 0x80000000)
    static let plaqueBottom = Color(argb: 0x4D000000)
    static let plaqueBorder = Color(argb: 0x668A6D3D)

    static let plaqueShadow = Color(argb: 0xFF3E2D13)
    static let clockShadow = Color(argb: 0xFF322611)

    // The raised-brass control (pills, chips, buttons).
    static let raisedInk = Color(argb: 0xFF1A0F08)
    static let raisedStroke = Color(argb: 0x80000000)
    static let raisedTopHighlight = Color(argb: 0x80FFF0B4)
    static let raisedBottomShadow = Color(argb: 0x66000000)
    static let raisedLabelShadow = Color(argb: 0x4DFFF0B4)

    static var brassBar: LinearGradient {
        LinearGradient(colors: [brass3, brass1, brassHighlight, brass1, brass3], startPoint: .top, endPoint: .bottom)
    }

    static var plaqueFill: LinearGradient {
        LinearGradient(colors: [plaqueTop, plaqueBottom], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Type

extension Font {
    static func playfair(_ size: CGFloat, semibold: Bool = false) -> Font {
        .custom(semibold ? "PlayfairDisplay-SemiBold" : "PlayfairDisplay-Regular", size: size)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Paper background

/// Warm paper: a vertical gradient, a soft light at the top, and a fine grain.
struct PaperBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [BrassPaper.gradientTop, BrassPaper.gradientBot], startPoint: .top, endPoint: .bottom)
                RadialGradient(
                    colors: [Color.white.opacity(0.80), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.35
                )
                Canvas { context, size in
                    var grain = Path()
                    var y: CGFloat = 0
                    while y < size.height {
                        grain.move(to: CGPoint(x: 0, y: y))
                        grain.addLine(to: CGPoint(x: size.width, y: y))
                        y += 4
                    }
                    var x: CGFloat = 0
                    while x < size.width {
                        grain.move(to: CGPoint(x: x, y: 0))
                        grain.addLine(to: CGPoint(x: x, y: size.height))
                        x += 5
                    }
                    context.stroke(grain, with: .color(BrassPaper.grain.opacity(0.04)), lineWidth: 0.5)
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Plaque card

/// The dark smoked-glass plaque every settings and catalog card sits on.
struct PlaqueCard<Content: View>: View {
    var cornerRadius: CGFloat = 14
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(BrassPaper.plaqueFill)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(BrassPaper.plaqueBorder, lineWidth: 1))
        .shadow(color: BrassPaper.plaqueShadow.opacity(0.30), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Raised brass

/// Polished brass with a lit top edge and a shaded bottom edge.
struct RaisedBrass: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BrassPaper.brassBar
                    VStack(spacing: 0) {
                        LinearGradient(colors: [BrassPaper.raisedTopHighlight, Color.clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 2)
                        Spacer(minLength: 0)
                        LinearGradient(colors: [Color.clear, BrassPaper.raisedBottomShadow], startPoint: .top, endPoint: .bottom)
                            .frame(height: 2)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(BrassPaper.raisedStroke, lineWidth: 1))
    }
}

/// A recessed dark control (an unselected chip or pill).
struct SunkenBrass: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color(argb: 0x66000000))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(BrassPaper.raisedStroke, lineWidth: 1))
    }
}

extension View {
    func raisedBrass(cornerRadius: CGFloat = 100) -> some View {
        modifier(RaisedBrass(cornerRadius: cornerRadius))
    }

    func sunkenBrass(cornerRadius: CGFloat = 100) -> some View {
        modifier(SunkenBrass(cornerRadius: cornerRadius))
    }

    /// The soft dark drop under light text on a plaque.
    func plaqueTextShadow() -> some View {
        shadow(color: Color.black.opacity(0.60), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Screw

struct BrassScrew: View {
    var size: CGFloat = 6

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: BrassPaper.screwLight, location: 0),
                        .init(color: BrassPaper.brass1, location: 0.7),
                        .init(color: BrassPaper.screwDark, location: 1)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .overlay(
                Capsule()
                    .fill(BrassPaper.screwDark)
                    .frame(width: size * 0.65, height: 1)
            )
            .frame(width: size, height: size)
    }
}

// MARK: - Labels

/// A section label on the light paper (outside a plaque).
struct SectionEyebrow: View {
    let text: String
    var size: CGFloat = 13
    var tracking: CGFloat = 2

    var body: some View {
        Text(text)
            .font(.playfair(size, semibold: true))
            .tracking(tracking)
            .foregroundColor(BrassPaper.ink.opacity(0.55))
            .padding(.leading, 6)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}

/// A raised-brass pill label (DAY 4 / 9, Active, a price).
struct BrassPillLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.mono(9, weight: .bold))
            .tracking(1.35)
            .foregroundColor(BrassPaper.raisedInk)
            .shadow(color: BrassPaper.raisedLabelShadow, radius: 0, x: 0, y: 1)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .raisedBrass()
    }
}

/// A dark pill label (Owned, Complete).
struct OwnedPillLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.mono(9, weight: .bold))
            .tracking(1.35)
            .foregroundColor(BrassPaper.inkSoft)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color(argb: 0x80000000))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color(argb: 0x40FFFFFF), lineWidth: 1))
    }
}
