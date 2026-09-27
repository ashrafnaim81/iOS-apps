import SwiftUI

struct WinView: View {
    let result: WinResult
    let onNext: () -> Void
    let onHome: () -> Void

    @State private var appear = false
    @State private var starsShown = 0
    @State private var badgePulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.45 : 0).ignoresSafeArea()
            ConfettiView().ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Puzzle Solved!")
                    .font(Theme.rounded(30, .heavy))
                    .foregroundColor(Theme.ink)
                Text(result.difficulty.displayName)
                    .font(Theme.rounded(15, .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Capsule().fill(result.difficulty.color))

                HStack(spacing: 14) {
                    ForEach(0..<3, id: \.self) { i in
                        let earned = i < result.stars
                        Image(systemName: earned ? "star.fill" : "star")
                            .font(.system(size: i == 1 ? 48 : 38, weight: .bold))
                            .foregroundColor(earned ? Theme.gold : Theme.inkSoft.opacity(0.4))
                            .shadow(color: earned ? Theme.gold.opacity(0.6) : .clear, radius: 10)
                            .scaleEffect(starsShown > i ? 1 : 0.1)
                            .opacity(starsShown > i ? 1 : 0)
                            .rotationEffect(.degrees(starsShown > i ? 0 : -90))
                            .offset(y: i == 1 ? -8 : 0)
                    }
                }
                .frame(height: 64)

                if result.isNewBest {
                    Label("New best time!", systemImage: "rosette")
                        .font(Theme.rounded(15, .bold))
                        .foregroundColor(Color(hex: 0xB7791F))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.gold.opacity(0.25)))
                        .scaleEffect(badgePulse ? 1.06 : 0.96)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: badgePulse)
                }

                HStack(spacing: 0) {
                    stat("Time", formatTime(result.time), "timer")
                    stat("Mistakes", "\(result.mistakes)", "xmark.circle")
                    stat("Hints", "\(result.hints)", "lightbulb")
                }
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceAlt))

                PrimaryButton(title: "Next Puzzle", systemImage: "arrow.right.circle.fill", action: onNext)
                PrimaryButton(title: "Home", filled: false, action: onHome)
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Theme.surface)
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
            )
            .padding(24)
            .scaleEffect(appear ? 1 : 0.7)
            .opacity(appear ? 1 : 0)
        }
        .onAppear(perform: animateIn)
    }

    private func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(Theme.accent)
            Text(value).font(Theme.rounded(20, .bold)).foregroundColor(Theme.ink).monospacedDigit()
            Text(title).font(Theme.rounded(12, .medium)).foregroundColor(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) { appear = true }
        badgePulse = true
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(i) * 0.28) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { starsShown = i + 1 }
                if i < result.stars {
                    SoundManager.shared.play(.star)
                    Haptics.impact(.medium)
                }
            }
        }
    }
}
