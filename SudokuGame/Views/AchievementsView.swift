import SwiftUI

struct AchievementsView: View {
    @ObservedObject var game: GameModel
    let onBack: () -> Void

    @State private var selected: Achievement?

    private var unlockedCount: Int { Achievement.allCases.filter { game.isUnlocked($0) }.count }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    HStack {
                        CircleIconButton(systemName: "chevron.left", action: onBack)
                            .accessibilityLabel("Back")
                        Spacer()
                        Text("Achievements").font(Theme.rounded(20, .bold)).foregroundColor(Theme.ink)
                        Spacer()
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.top, 6)

                    summary

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                        ForEach(Achievement.allCases) { a in
                            let unlocked = game.isUnlocked(a)
                            Button {
                                SoundManager.shared.play(.tap)
                                Haptics.selection()
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    selected = selected == a ? nil : a
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    AchievementBadge(achievement: a, unlocked: unlocked, size: 66)
                                    Text(a.title)
                                        .font(Theme.rounded(13, .bold))
                                        .foregroundColor(unlocked ? Theme.ink : Theme.inkSoft)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                }
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(selected == a ? a.color.opacity(0.14) : Theme.surface)
                                )
                            }
                            .buttonStyle(PressableStyle(scale: 0.94))
                        }
                    }

                    if let a = selected {
                        HStack(spacing: 14) {
                            AchievementBadge(achievement: a, unlocked: game.isUnlocked(a), size: 50)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(a.title).font(Theme.rounded(17, .bold)).foregroundColor(Theme.ink)
                                Text(a.detail).font(Theme.rounded(14, .medium)).foregroundColor(Theme.inkSoft)
                                Text(game.isUnlocked(a) ? "Unlocked" : "Locked")
                                    .font(Theme.rounded(12, .heavy))
                                    .foregroundColor(game.isUnlocked(a) ? a.color : Theme.inkSoft)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 14) {
            SantaiCat(mood: unlockedCount > 0 ? .happy : .idle, size: 84)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(unlockedCount) of \(Achievement.allCases.count) unlocked")
                    .font(Theme.rounded(18, .bold)).foregroundColor(Theme.ink)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.surfaceAlt)
                        Capsule().fill(Theme.brandGradient)
                            .frame(width: geo.size.width * CGFloat(unlockedCount) / CGFloat(Achievement.allCases.count))
                    }
                }
                .frame(height: 10)
                HStack(spacing: 14) {
                    Label("\(game.stats.bestStreak) best streak", systemImage: "flame.fill")
                        .foregroundColor(Color(hex: 0xE0521F))
                    Label("\(game.stats.flawless) flawless", systemImage: "checkmark.seal.fill")
                        .foregroundColor(Color(hex: 0x2FB36E))
                }
                .font(Theme.rounded(12, .bold))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.surface))
    }
}
