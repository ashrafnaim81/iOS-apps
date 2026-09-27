import SwiftUI

struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(animatableData * .pi * 6), y: 0))
    }
}

struct CircleIconButton: View {
    let systemName: String
    var tint: Color = Theme.ink
    var background: Color = Theme.surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .background(Circle().fill(background))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(PressableStyle(scale: 0.88))
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var filled = true
    let action: () -> Void

    var body: some View {
        Button {
            SoundManager.shared.play(.button)
            Haptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(Theme.rounded(19, .bold))
            .foregroundColor(filled ? .white : Theme.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(filled ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.surfaceAlt))
            )
            .shadow(color: filled ? Theme.accent.opacity(0.35) : .clear, radius: 12, y: 6)
        }
        .buttonStyle(PressableStyle())
    }
}

/// The 3×3 brand mark. Tiles pop in one after another when `animated` is true.
struct LogoGrid: View {
    var size: CGFloat = 140
    var animated = true
    private let digits = [5, 0, 7, 0, 3, 0, 1, 0, 9]
    @State private var shown = false

    var body: some View {
        let gap = size * 0.05
        let tile = (size - gap * 2) / 3
        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { c in
                        tileView(r * 3 + c, tile: tile)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if animated {
                shown = true
            }
        }
    }

    private func tileView(_ i: Int, tile: CGFloat) -> some View {
        let visible = shown || !animated
        return ZStack {
            RoundedRectangle(cornerRadius: tile * 0.22, style: .continuous)
                .fill(Color.white.opacity(digits[i] == 0 ? 0.28 : 1))
            if digits[i] != 0 {
                Text("\(digits[i])")
                    .font(Theme.rounded(tile * 0.58, .heavy))
                    .foregroundColor(Theme.accentDeep)
            }
        }
        .frame(width: tile, height: tile)
        .scaleEffect(visible ? 1 : 0.2)
        .opacity(visible ? 1 : 0)
        .rotationEffect(.degrees(visible ? 0 : -25))
        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(i) * 0.06), value: visible)
    }
}

/// Slowly drifting digits used behind the splash and home screens.
struct FloatingDigitsBackground: View {
    private struct Seed {
        let x: Double, y: Double, speed: Double, size: Double, digit: Int, opacity: Double, spin: Double
    }

    private let seeds: [Seed] = {
        var state: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(1 << 53)
        }
        return (0..<22).map { _ in
            Seed(x: next(), y: next(), speed: 8 + next() * 18, size: 22 + next() * 44,
                 digit: 1 + Int(next() * 9) % 9, opacity: 0.06 + next() * 0.12, spin: next() * 2 - 1)
        }
    }()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let span = size.height + 120
                for seed in seeds {
                    let rawY = seed.y * span - t * seed.speed
                    let y = rawY - (rawY / span).rounded(.down) * span - 60
                    let x = seed.x * size.width + sin(t * 0.3 + seed.y * 10) * 12
                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .degrees(t * seed.spin * 10))
                    ctx.opacity = seed.opacity
                    ctx.draw(Text("\(seed.digit)")
                                .font(.system(size: seed.size, weight: .heavy, design: .rounded))
                                .foregroundColor(.white),
                             at: .zero)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
