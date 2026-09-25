import Foundation
import SwiftUI

// MARK: - ClockAngles

/// Hand angles in degrees, clockwise from twelve (Android ClockState.kt).
struct ClockAngles: Equatable {
    let hour: Double
    let minute: Double
    let second: Double

    init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour12 = Double((parts.hour ?? 0) % 12)
        let minute = Double(parts.minute ?? 0)
        let second = Double(parts.second ?? 0)
        self.hour = hour12 * 30 + minute * 0.5
        self.minute = minute * 6 + second * 0.1
        self.second = second * 6
    }
}

// MARK: - AnalogClockFace
//
// The app's signature object: a brass-bezelled face with Roman numerals,
// lance hands and a rust second hand. Geometry is Android's
// AnalogClockFace.kt, laid out for a 330-point face and scaled to fit.

struct AnalogClockFace: View {
    let date: Date

    private static let numerals = ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]

    var body: some View {
        GeometryReader { geo in
            let diameter = min(geo.size.width, geo.size.height)
            let s = diameter / 330
            let angles = ClockAngles(date: date)

            ZStack {
                // Outer ring
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                BrassPaper.brass3.opacity(0.70),
                                BrassPaper.brass2.opacity(0.80),
                                BrassPaper.brassHighlight.opacity(0.60),
                                BrassPaper.brass2.opacity(0.80),
                                BrassPaper.brass3.opacity(0.70)
                            ]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )

                // Inner bezel
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: BrassPaper.brass2.opacity(0.50), location: 0),
                                .init(color: BrassPaper.brass2.opacity(0.35), location: 0.70),
                                .init(color: BrassPaper.brass3.opacity(0.45), location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: diameter / 2 - 6
                        )
                    )
                    .overlay(Circle().stroke(BrassPaper.brassDeep.opacity(0.30), lineWidth: 1))
                    .padding(6)

                // Face
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: BrassPaper.clockFaceBg, location: 0),
                                .init(color: BrassPaper.clockFaceWarm, location: 0.50),
                                .init(color: BrassPaper.clockFaceWarm.opacity(0.85), location: 0.82),
                                .init(color: BrassPaper.clockFaceWarm.opacity(0.70), location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: diameter / 2 - 11
                        )
                    )
                    .overlay(Circle().stroke(BrassPaper.clockBorder.opacity(0.28), lineWidth: 1))
                    .padding(11)

                ClockTicks(scale: s)
                    .padding(11)

                brandText("UPTIME", scale: s)
                    .offset(y: -46 * s)
                brandText("PRIZES", scale: s)
                    .offset(y: 46 * s)

                ForEach(0..<12, id: \.self) { index in
                    numeral(index, scale: s)
                }

                LanceHand(
                    degrees: angles.hour, length: 88 * s, baseWidth: 6 * s, tailLength: 14 * s,
                    tailWidth: 3.5 * s, fill: BrassPaper.handDark, highlight: BrassPaper.handLight
                )
                LanceHand(
                    degrees: angles.minute, length: 118 * s, baseWidth: 4.5 * s, tailLength: 16 * s,
                    tailWidth: 2.5 * s, fill: BrassPaper.handMinDark, highlight: BrassPaper.handMinLight
                )
                SecondHand(degrees: angles.second, scale: s)

                CenterCap(scale: s)
            }
            .frame(width: diameter, height: diameter)
            .shadow(color: BrassPaper.clockShadow.opacity(0.80), radius: 22 * s, x: 0, y: 12 * s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text(date, style: .time))
    }

    private func brandText(_ text: String, scale s: CGFloat) -> some View {
        Text(text)
            .font(.playfair(9 * s, semibold: true))
            .tracking(9 * s * 0.45)
            .foregroundColor(BrassPaper.clockText.opacity(0.85))
            .shadow(color: Color.white.opacity(0.60), radius: 0.5, x: 0, y: 1.2)
    }

    private func numeral(_ index: Int, scale s: CGFloat) -> some View {
        let radius = 116 * s
        let angle = Double(index) * Double.pi / 6
        let large = index % 3 == 0
        return Text(Self.numerals[index])
            .font(.playfair((large ? 17 : 14) * s, semibold: true))
            .foregroundColor(BrassPaper.clockNumeral)
            .shadow(color: BrassPaper.numeralEngrave, radius: 0.6, x: 0, y: 1.2)
            .offset(x: radius * CGFloat(sin(angle)), y: -radius * CGFloat(cos(angle)))
    }
}

// MARK: - Ticks

private struct ClockTicks: View {
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = size.width / 2 - 6 * scale
            for i in 0..<60 {
                let angle = (Double(i) * 6 - 90) * Double.pi / 180
                let isHour = i % 5 == 0
                let length = (isHour ? 14 : 5) * scale
                let width = (isHour ? 2.5 : 1) * scale
                var tick = Path()
                tick.move(to: CGPoint(
                    x: center.x + CGFloat(cos(angle)) * (outer - length),
                    y: center.y + CGFloat(sin(angle)) * (outer - length)
                ))
                tick.addLine(to: CGPoint(
                    x: center.x + CGFloat(cos(angle)) * outer,
                    y: center.y + CGFloat(sin(angle)) * outer
                ))
                context.stroke(
                    tick,
                    with: .color(BrassPaper.clockNumeral),
                    style: StrokeStyle(lineWidth: width, lineCap: .round)
                )
            }
        }
    }
}

// MARK: - Hands

/// A slim lance: sharp tip, widest at the shoulder, tapering to a tail
/// behind the pivot.
private struct LanceHand: View {
    let degrees: Double
    let length: CGFloat
    let baseWidth: CGFloat
    let tailLength: CGFloat
    let tailWidth: CGFloat
    let fill: Color
    let highlight: Color

    var body: some View {
        let height = length + tailLength
        let pivot = length / height
        Canvas { context, size in
            let cx = size.width / 2
            let pivotY = size.height * pivot
            let shoulderY = pivotY * 0.78
            var lance = Path()
            lance.move(to: CGPoint(x: cx, y: 0))
            lance.addLine(to: CGPoint(x: cx + baseWidth / 2, y: shoulderY))
            lance.addLine(to: CGPoint(x: cx + tailWidth / 2, y: pivotY))
            lance.addLine(to: CGPoint(x: cx, y: size.height))
            lance.addLine(to: CGPoint(x: cx - tailWidth / 2, y: pivotY))
            lance.addLine(to: CGPoint(x: cx - baseWidth / 2, y: shoulderY))
            lance.closeSubpath()
            context.fill(
                lance,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: highlight, location: 0),
                        .init(color: fill, location: 0.45),
                        .init(color: fill.opacity(0.75), location: 1)
                    ]),
                    startPoint: CGPoint(x: cx, y: 0),
                    endPoint: CGPoint(x: cx, y: pivotY)
                )
            )
            var spine = Path()
            spine.move(to: CGPoint(x: cx, y: 2))
            spine.addLine(to: CGPoint(x: cx, y: pivotY * 0.85))
            context.stroke(
                spine,
                with: .color(highlight.opacity(0.55)),
                style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
            )
        }
        .frame(width: baseWidth, height: height)
        .rotationEffect(.degrees(degrees), anchor: UnitPoint(x: 0.5, y: pivot))
        .offset(y: height * (0.5 - pivot))
    }
}

/// An ultra-thin rust shaft with a small lozenge counterweight.
private struct SecondHand: View {
    let degrees: Double
    let scale: CGFloat

    var body: some View {
        let width = 10 * scale
        let height = 148 * scale
        let pivot: CGFloat = 0.82
        Canvas { context, size in
            let cx = size.width / 2
            let pivotY = size.height * pivot
            var shaft = Path()
            shaft.move(to: CGPoint(x: cx, y: 1.5))
            shaft.addLine(to: CGPoint(x: cx, y: pivotY - 2 * scale))
            context.stroke(
                shaft,
                with: .color(BrassPaper.handSecRust),
                style: StrokeStyle(lineWidth: 1.2 * scale, lineCap: .round)
            )
            let halfH = 7 * scale
            let halfW = 2.8 * scale
            let centerY = pivotY + halfH + scale
            var lozenge = Path()
            lozenge.move(to: CGPoint(x: cx, y: centerY - halfH))
            lozenge.addLine(to: CGPoint(x: cx + halfW, y: centerY))
            lozenge.addLine(to: CGPoint(x: cx, y: centerY + halfH))
            lozenge.addLine(to: CGPoint(x: cx - halfW, y: centerY))
            lozenge.closeSubpath()
            context.fill(lozenge, with: .color(BrassPaper.handSecRust))
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(degrees), anchor: UnitPoint(x: 0.5, y: pivot))
        .offset(y: height * (0.5 - pivot))
    }
}

// MARK: - Center cap

private struct CenterCap: View {
    let scale: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: BrassPaper.centerCapLight, location: 0),
                            .init(color: BrassPaper.centerCapMid, location: 0.45),
                            .init(color: BrassPaper.centerCapDark, location: 0.85),
                            .init(color: BrassPaper.centerCapEdge, location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 20 * scale
                    )
                )
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                .frame(width: 40 * scale, height: 40 * scale)
                .shadow(color: Color.black.opacity(0.30), radius: 2, x: 0, y: 2)

            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: BrassPaper.brassHighlight, location: 0),
                            .init(color: BrassPaper.brass2, location: 0.7),
                            .init(color: BrassPaper.brass3, location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 12 * scale
                    )
                )
                .overlay(Circle().stroke(BrassPaper.brassDeep.opacity(0.45), lineWidth: 1))
                .frame(width: 24 * scale, height: 24 * scale)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [BrassPaper.brassHighlight, BrassPaper.brass1],
                        center: .center,
                        startRadius: 0,
                        endRadius: 4 * scale
                    )
                )
                .frame(width: 8 * scale, height: 8 * scale)
        }
    }
}
