import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    private let pageCount = 4

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        SoundManager.shared.play(.button)
                        onFinish()
                    }
                    .font(Theme.rounded(16, .semibold))
                    .foregroundColor(Theme.inkSoft)
                    .opacity(page < pageCount - 1 ? 1 : 0)
                }
                .padding(.horizontal, 24)
                .frame(height: 44)

                TabView(selection: $page) {
                    OnboardingPage(title: "Welcome to\nSudoku Santai",
                                   text: "A calm, classic number puzzle. No ads, no accounts. Just you and the grid.") {
                        ZStack {
                            Circle().fill(Theme.brandGradient).frame(width: 230, height: 230)
                            LogoGrid(size: 130)
                        }
                    }
                    .tag(0)
                    OnboardingPage(title: "The Only Rule",
                                   text: "Every row, every column and every 3×3 box must contain the numbers 1 to 9, each exactly once.") {
                        RuleIllustration()
                    }
                    .tag(1)
                    OnboardingPage(title: "Tap, Then Choose",
                                   text: "Tap an empty cell, then tap a number below the board. Matching numbers light up to guide you.") {
                        TapIllustration()
                    }
                    .tag(2)
                    OnboardingPage(title: "Play Your Way",
                                   text: "Mistakes turn red. Undo, erase or ask for a hint anytime. Solve with no mistakes and no hints to earn 3 stars.") {
                        HelpersIllustration()
                    }
                    .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: page) { _ in Haptics.selection() }

                HStack(spacing: 8) {
                    ForEach(0..<pageCount, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? Theme.accent : Theme.inkSoft.opacity(0.3))
                            .frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: page)
                .padding(.bottom, 24)

                PrimaryButton(title: page == pageCount - 1 ? "Let's Play" : "Next",
                              systemImage: page == pageCount - 1 ? "play.fill" : nil) {
                    if page < pageCount - 1 {
                        withAnimation(.easeInOut(duration: 0.35)) { page += 1 }
                    } else {
                        onFinish()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: 480)
            }
        }
    }
}

private struct OnboardingPage<Illustration: View>: View {
    let title: String
    let text: String
    @ViewBuilder let illustration: () -> Illustration

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            illustration()
                .frame(height: 260)
            Text(title)
                .font(Theme.rounded(30, .heavy))
                .foregroundColor(Theme.ink)
                .multilineTextAlignment(.center)
            Text(text)
                .font(Theme.rounded(17, .medium))
                .foregroundColor(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 520)
    }
}

// MARK: - Illustrations

/// Cycles the highlight between a row, a column and a box.
private struct RuleIllustration: View {
    private let digits: [Int] = [
        5, 3, 0, 0, 7, 0, 0, 0, 0,
        6, 0, 0, 1, 9, 5, 0, 0, 0,
        0, 9, 8, 0, 0, 0, 0, 6, 0,
        8, 0, 0, 0, 6, 0, 0, 0, 3,
        4, 0, 0, 8, 0, 3, 0, 0, 1,
        7, 0, 0, 0, 2, 0, 0, 0, 6,
        0, 6, 0, 0, 0, 0, 2, 8, 0,
        0, 0, 0, 4, 1, 9, 0, 0, 5,
        0, 0, 0, 0, 8, 0, 0, 7, 9,
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.4)) { timeline in
            let phase = Int(timeline.date.timeIntervalSinceReferenceDate / 1.4) % 3
            VStack(spacing: 14) {
                board(phase: phase)
                Text(["Each row", "Each column", "Each 3×3 box"][phase])
                    .font(Theme.rounded(16, .bold))
                    .foregroundColor(Theme.accent)
                    .id(phase)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.4), value: phase)
        }
    }

    private func board(phase: Int) -> some View {
        let side: CGFloat = 216
        let cell = side / 9
        return VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { c in
                        let lit = highlighted(r: r, c: c, phase: phase)
                        ZStack {
                            Rectangle().fill(lit ? Theme.sameNumber : Theme.surface)
                            if digits[r * 9 + c] != 0 {
                                Text("\(digits[r * 9 + c])")
                                    .font(Theme.rounded(cell * 0.55, .semibold))
                                    .foregroundColor(Theme.ink)
                            }
                        }
                        .frame(width: cell, height: cell)
                    }
                }
            }
        }
        .overlay(GridLines(thin: Theme.thinLine, thick: Theme.thickLine, thinWidth: 0.7, thickWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.thickLine, lineWidth: 2))
        .shadow(color: Theme.accentDeep.opacity(0.12), radius: 12, y: 6)
    }

    private func highlighted(r: Int, c: Int, phase: Int) -> Bool {
        switch phase {
        case 0: return r == 4
        case 1: return c == 4
        default: return r / 3 == 1 && c / 3 == 1
        }
    }
}

/// Shows a finger selecting a cell and a number popping into it.
private struct TapIllustration: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.8)) { timeline in
            let step = Int(timeline.date.timeIntervalSinceReferenceDate / 0.8) % 4
            VStack(spacing: 22) {
                miniBoard(step: step)
                miniPad(step: step)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: step)
        }
    }

    private func miniBoard(step: Int) -> some View {
        let digits = [2, 0, 9, 0, 0, 1, 7, 3, 0]
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let i = r * 3 + c
                        let isTarget = i == 4
                        ZStack {
                            Rectangle().fill(isTarget && step >= 1 ? Theme.selected : Theme.surface)
                            if digits[i] != 0 {
                                Text("\(digits[i])").font(Theme.rounded(28, .semibold)).foregroundColor(Theme.ink)
                            } else if isTarget && step >= 2 {
                                Text("4").font(Theme.rounded(28, .semibold)).foregroundColor(Theme.userDigit)
                                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                            }
                            if isTarget && step == 1 {
                                Image(systemName: "hand.point.up.left.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(Theme.accentDeep)
                                    .offset(x: 18, y: 24)
                                    .transition(.opacity)
                            }
                        }
                        .frame(width: 58, height: 58)
                    }
                }
            }
        }
        .overlay(GridLines3(color: Theme.thinLine))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.thickLine, lineWidth: 2.5))
        .shadow(color: Theme.accentDeep.opacity(0.12), radius: 12, y: 6)
    }

    private func miniPad(step: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(3...6, id: \.self) { n in
                let pressed = n == 4 && step == 2
                Text("\(n)")
                    .font(Theme.rounded(22, .semibold))
                    .foregroundColor(pressed ? .white : Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(pressed ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.surface)))
                    .scaleEffect(pressed ? 0.88 : 1)
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
            }
        }
    }
}

private struct GridLines3: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for k in 1..<3 {
                let x = size.width * CGFloat(k) / 3, y = size.height * CGFloat(k) / 3
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(color), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Undo / Erase / Hint tiles, a shaking wrong digit and three stars.
private struct HelpersIllustration: View {
    @State private var shake: CGFloat = 0
    @State private var starsOn = false

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 12) {
                tile("arrow.uturn.backward", "Undo", Theme.accent)
                tile("eraser", "Erase", Theme.accent)
                tile("lightbulb.fill", "Hint", Color(hex: 0xE0A100))
            }
            HStack(spacing: 20) {
                Text("7")
                    .font(Theme.rounded(30, .semibold))
                    .foregroundColor(Theme.error)
                    .frame(width: 58, height: 58)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.errorBackground))
                    .modifier(ShakeEffect(animatableData: shake))
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: "star.fill")
                            .font(.system(size: i == 1 ? 36 : 28))
                            .foregroundColor(Theme.gold)
                            .scaleEffect(starsOn ? 1 : 0.4)
                            .opacity(starsOn ? 1 : 0.3)
                            .animation(.spring(response: 0.45, dampingFraction: 0.5).delay(Double(i) * 0.12), value: starsOn)
                    }
                }
            }
        }
        .onAppear {
            starsOn = true
            withAnimation(.linear(duration: 0.5).delay(0.3)) { shake += 1 }
        }
        .onDisappear { starsOn = false }
    }

    private func tile(_ icon: String, _ title: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 24, weight: .semibold))
            Text(title).font(Theme.rounded(13, .semibold))
        }
        .foregroundColor(tint)
        .frame(width: 84, height: 76)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}
