import SwiftUI

struct ConfettiView: View {
    private struct Piece {
        let x: CGFloat, y: CGFloat
        let vx: CGFloat, vy: CGFloat
        let spin: Double, size: CGFloat, wobble: Double
        let color: Color, isCircle: Bool, delay: Double
    }

    private static let palette: [Color] = [
        Color(hex: 0x3A8BFF), Color(hex: 0xFFC53D), Color(hex: 0x2FB36E),
        Color(hex: 0xFF6B8A), Color(hex: 0x8B5CF6), Color(hex: 0x33D1E0),
    ]

    @State private var pieces: [Piece] = []
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let lt = t - p.delay
                    if lt <= 0 { continue }
                    let dt = CGFloat(lt)
                    let x = p.x * size.width + p.vx * dt + CGFloat(sin(lt * p.wobble)) * 14
                    let y = p.y * size.height + p.vy * dt + 520 * dt * dt
                    if y > size.height + 30 { continue }
                    var ctx = context
                    ctx.opacity = max(0, min(1, 4.5 - lt))
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(p.spin * lt))
                    let rect = CGRect(x: -p.size / 2, y: -p.size * 0.3, width: p.size, height: p.size * 0.6)
                    let path = p.isCircle ? Path(ellipseIn: rect.insetBy(dx: p.size * 0.15, dy: -p.size * 0.05)) : Path(rect)
                    ctx.fill(path, with: .color(p.color))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            pieces = (0..<90).map { _ in burst() } + (0..<70).map { _ in rain() }
        }
    }

    private func burst() -> Piece {
        Piece(x: .random(in: 0.42...0.58), y: 0.42,
              vx: .random(in: -380...380), vy: .random(in: -820...(-320)),
              spin: .random(in: -9...9), size: .random(in: 8...14), wobble: .random(in: 3...8),
              color: Self.palette.randomElement()!, isCircle: Bool.random(), delay: .random(in: 0...0.12))
    }

    private func rain() -> Piece {
        Piece(x: .random(in: 0...1), y: -0.05,
              vx: .random(in: -40...40), vy: .random(in: 40...160),
              spin: .random(in: -6...6), size: .random(in: 7...12), wobble: .random(in: 2...6),
              color: Self.palette.randomElement()!, isCircle: Bool.random(), delay: .random(in: 0.2...1.4))
    }
}
