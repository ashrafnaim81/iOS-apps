import SwiftUI

struct WinView: View {
    let result: WinResult
    let onNext: () -> Void
    let onHome: () -> Void
    let onCalendar: () -> Void

    @State private var appear = false
    @State private var starsShown = 0
    @State private var badgesShown = false

    var body: some View {
        ZStack {
            Color.black.opacity(appear ? 0.45 : 0).ignoresSafeArea()
            ConfettiView().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    SantaiCat(mood: .dance, size: 130)
                        .padding(.bottom, -26)
                        .zIndex(1)
                    card
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
            }
            .scaleEffect(appear ? 1 : 0.7)
            .opacity(appear ? 1 : 0)
        }
        .onAppear(perform: animateIn)
    }

    private var card: some View {
        VStack(spacing: 16) {
            Text(result.isDaily ? "Daily Complete!" : "Puzzle Solved!")
                .font(Theme.rounded(28, .heavy))
                .foregroundColor(Theme.ink)
                .padding(.top, 18)
            HStack(spacing: 8) {
                chip(result.difficulty.displayName, result.difficulty.color)
                if let day = result.dayKey { chip(DayKey.shortLabel(for: day), Color(hex: 0xE84E8A)) }
            }

            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { i in
                    let earned = i < result.stars
                    Image(systemName: earned ? "star.fill" : "star")
                        .font(.system(size: i == 1 ? 46 : 36, weight: .bold))
                        .foregroundColor(earned ? Theme.gold : Theme.inkSoft.opacity(0.4))
                        .shadow(color: earned ? Theme.gold.opacity(0.6) : .clear, radius: 10)
                        .scaleEffect(starsShown > i ? 1 : 0.1)
                        .opacity(starsShown > i ? 1 : 0)
                        .rotationEffect(.degrees(starsShown > i ? 0 : -90))
                        .offset(y: i == 1 ? -8 : 0)
                }
            }
            .frame(height: 60)

            HStack(spacing: 8) {
                if result.isNewBest {
                    pill("New best time!", icon: "rosette", color: Color(hex: 0xB7791F), bg: Theme.gold.opacity(0.25))
                }
                if result.streak > 1 {
                    pill("\(result.streak)-day streak", icon: "flame.fill", color: Color(hex: 0xE0521F),
                         bg: Color(hex: 0xF0602A).opacity(0.15))
                }
            }

            HStack(spacing: 0) {
                stat("Time", formatTime(result.time), "timer")
                stat("Mistakes", "\(result.mistakes)", "xmark.circle")
                stat("Hints", "\(result.hints)", "lightbulb")
            }
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surfaceAlt))

            if !result.newAchievements.isEmpty {
                VStack(spacing: 8) {
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(Theme.rounded(12, .heavy))
                        .foregroundColor(Theme.inkSoft)
                    ForEach(Array(result.newAchievements.enumerated()), id: \.element) { index, a in
                        HStack(spacing: 12) {
                            AchievementBadge(achievement: a, unlocked: true, size: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.title).font(Theme.rounded(16, .bold)).foregroundColor(Theme.ink)
                                Text(a.detail).font(Theme.rounded(13, .medium)).foregroundColor(Theme.inkSoft)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(a.color.opacity(0.12)))
                        .scaleEffect(badgesShown ? 1 : 0.6)
                        .opacity(badgesShown ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6).delay(Double(index) * 0.12), value: badgesShown)
                    }
                }
            }

            if result.isDaily {
                PrimaryButton(title: "Daily Calendar", systemImage: "calendar", action: onCalendar)
            } else {
                PrimaryButton(title: "Next Puzzle", systemImage: "arrow.right.circle.fill", action: onNext)
            }
            PrimaryButton(title: "Home", filled: false, action: onHome)
        }
        .padding(22)
        .frame(maxWidth: 420)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
        )
        .padding(.horizontal, 22)
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(Theme.rounded(14, .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(color))
    }

    private func pill(_ text: String, icon: String, color: Color, bg: Color) -> some View {
        Label(text, systemImage: icon)
            .font(Theme.rounded(14, .bold))
            .foregroundColor(color)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Capsule().fill(bg))
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
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(i) * 0.28) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) { starsShown = i + 1 }
                if i < result.stars {
                    SoundManager.shared.play(.star)
                    Haptics.impact(.medium)
                }
            }
        }
        if !result.newAchievements.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                badgesShown = true
                SoundManager.shared.play(.group)
                Haptics.notify(.success)
            }
        }
    }
}

/// Round achievement medal; unlocked ones shimmer.
struct AchievementBadge: View {
    let achievement: Achievement
    let unlocked: Bool
    var size: CGFloat = 64

    var body: some View {
        ZStack {
            Circle()
                .fill(unlocked
                      ? AnyShapeStyle(LinearGradient(colors: [achievement.color.opacity(0.75), achievement.color],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                      : AnyShapeStyle(Theme.surfaceAlt))
            Circle().strokeBorder(Color.white.opacity(unlocked ? 0.6 : 0), lineWidth: size * 0.05)
            Image(systemName: unlocked ? achievement.icon : "lock.fill")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(unlocked ? .white : Theme.inkSoft.opacity(0.6))
            if unlocked {
                TimelineView(.animation) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3) / 3
                    LinearGradient(colors: [.clear, .white.opacity(0.55), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: size * 0.45)
                        .rotationEffect(.degrees(20))
                        .offset(x: size * CGFloat(phase * 2.4 - 1.2))
                }
                .clipShape(Circle())
                .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: unlocked ? achievement.color.opacity(0.4) : .clear, radius: 6, y: 3)
    }
}
