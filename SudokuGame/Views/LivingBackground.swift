import SwiftUI

/// Animated backdrop whose palette follows the time of day: bright mornings,
/// a warm sunset in the evening and a starry sky at night.
struct LivingBackground: View {
    private enum Period { case morning, day, evening, night }

    #if DEBUG
    /// Pins the time of day so App Store screenshots look the same on every run.
    static var overrideHour: Int?
    #endif

    private static var hour: Int {
        #if DEBUG
        if let overrideHour { return overrideHour }
        #endif
        return Calendar.current.component(.hour, from: Date())
    }

    private static var period: Period {
        switch hour {
        case 5..<11: return .morning
        case 11..<17: return .day
        case 17..<20: return .evening
        default: return .night
        }
    }

    private static func palette(_ p: Period) -> [Color] {
        switch p {
        case .morning: return [Color(hex: 0x5BB2FF), Color(hex: 0x2F74E8), Color(hex: 0x1C4DBA)]
        case .day: return [Color(hex: 0x3A8BFF), Color(hex: 0x1D4FCB), Color(hex: 0x14307F)]
        case .evening: return [Color(hex: 0xFF9A6B), Color(hex: 0xC2548F), Color(hex: 0x4B2D8F)]
        case .night: return [Color(hex: 0x2A3F85), Color(hex: 0x141D4A), Color(hex: 0x080C22)]
        }
    }

    private struct Speck {
        let x: Double, y: Double, r: Double, speed: Double, phase: Double
    }

    private let specks: [Speck] = {
        var state: UInt64 = 0x51A7_7A11
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
        return (0..<40).map { _ in
            Speck(x: next(), y: next(), r: next(), speed: 0.3 + next(), phase: next() * 6.28)
        }
    }()

    var body: some View {
        let period = Self.period
        let colors = Self.palette(period)
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let drift = CGFloat(sin(t * 0.08)) * 0.25
            ZStack {
                LinearGradient(colors: colors,
                               startPoint: UnitPoint(x: 0.2 + drift, y: 0),
                               endPoint: UnitPoint(x: 0.8 - drift, y: 1))
                Canvas { context, size in
                    if period == .night {
                        drawStars(context, size: size, t: t)
                    } else {
                        drawBokeh(context, size: size, t: t, warm: period == .evening)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func drawStars(_ context: GraphicsContext, size: CGSize, t: Double) {
        for s in specks {
            let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * (1 + s.speed * 2) + s.phase))
            let r = CGFloat(0.8 + s.r * 1.8)
            let p = CGPoint(x: s.x * size.width, y: s.y * size.height * 0.75)
            context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(twinkle)))
        }
        // An occasional shooting star.
        let cycle = t.truncatingRemainder(dividingBy: 9)
        if cycle < 0.9 {
            let k = CGFloat(cycle / 0.9)
            let start = CGPoint(x: size.width * 0.15, y: size.height * 0.12)
            let head = CGPoint(x: start.x + size.width * 0.55 * k, y: start.y + size.height * 0.18 * k)
            var trail = Path()
            trail.move(to: CGPoint(x: head.x - 60 * min(k * 3, 1), y: head.y - 20 * min(k * 3, 1)))
            trail.addLine(to: head)
            context.stroke(trail, with: .linearGradient(Gradient(colors: [.clear, .white.opacity(Double(1 - k))]),
                                                        startPoint: trail.boundingRect.origin, endPoint: head),
                           lineWidth: 2)
        }
    }

    private func drawBokeh(_ context: GraphicsContext, size: CGSize, t: Double, warm: Bool) {
        for (i, s) in specks.prefix(14).enumerated() {
            let r = CGFloat(30 + s.r * 70)
            let span = size.height + r * 2
            let rawY = s.y * Double(span) - t * s.speed * 6
            let y = CGFloat(rawY - (rawY / Double(span)).rounded(.down) * Double(span)) - r
            let x = CGFloat(s.x) * size.width + CGFloat(sin(t * 0.2 + s.phase)) * 30
            let tint: Color = warm && i % 2 == 0 ? Color(hex: 0xFFD29A) : .white
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: rect),
                         with: .radialGradient(Gradient(colors: [tint.opacity(0.14), tint.opacity(0)]),
                                               center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
        }
    }
}
