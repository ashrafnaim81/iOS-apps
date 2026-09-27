import SwiftUI

struct HomeView: View {
    @ObservedObject var game: GameModel
    let onPlay: () -> Void
    let onDaily: () -> Void
    let onAchievements: () -> Void
    let onShowTutorial: () -> Void

    @State private var showSettings = false
    @State private var showDifficulty = false
    @State private var appear = false
    @State private var pending: Difficulty?
    @State private var catMood: CatMood = .wave

    private let today = DayKey.today()

    var body: some View {
        ZStack {
            LivingBackground()
            FloatingDigitsBackground().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    hero
                    dailyCard
                        .padding(.top, 18)
                    buttons
                        .padding(.top, 14)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 20)

            if showDifficulty {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { closeSheet() }
                    .transition(.opacity)
                    .zIndex(1)
                VStack {
                    Spacer()
                    difficultyPanel
                }
                .transition(.move(edge: .bottom))
                .zIndex(2)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onShowTutorial: {
                showSettings = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onShowTutorial() }
            })
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appear = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { catMood = .idle }
        }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack(spacing: 10) {
            StreakChip(streak: game.stats.currentStreak)
            Spacer()
            CircleIconButton(systemName: "rosette", tint: .white, background: .white.opacity(0.18), action: onAchievements)
                .accessibilityLabel("Achievements")
            CircleIconButton(systemName: "gearshape.fill", tint: .white, background: .white.opacity(0.18)) {
                showSettings = true
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var hero: some View {
        VStack(spacing: 0) {
            SantaiCat(mood: catMood, size: 132)
                .padding(.bottom, -30)
                .zIndex(1)
                .onTapGesture {
                    SoundManager.shared.play(.star)
                    Haptics.impact(.light)
                    catMood = .happy
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { catMood = .idle }
                }
            LogoGrid(size: 118)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
            Text("Sudoku Santai")
                .font(Theme.rounded(38, .heavy))
                .foregroundColor(.white)
                .padding(.top, 18)
            Text("Relax. Think. Solve.")
                .font(Theme.rounded(16, .medium))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 2)
            HStack(spacing: 10) {
                statChip(icon: "checkmark.seal.fill", value: "\(game.stats.totalSolved)", label: "Solved")
                statChip(icon: "star.fill", value: "\(game.stats.totalStars)", label: "Stars")
            }
            .padding(.top, 14)
        }
        .padding(.top, 4)
    }

    private var dailyCard: some View {
        let done = game.stats.dailyStars[today] != nil
        return Button {
            SoundManager.shared.play(.button)
            Haptics.impact(.light)
            onDaily()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 52, height: 56)
                    VStack(spacing: 0) {
                        Text(monthShort).font(Theme.rounded(11, .heavy)).foregroundColor(Color(hex: 0xE84E8A))
                        Text(dayNumber).font(Theme.rounded(24, .heavy)).foregroundColor(Theme.ink)
                    }
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: 0x2FB36E))
                            .background(Circle().fill(Color.white))
                            .offset(x: 24, y: -24)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Challenge").font(Theme.rounded(19, .bold))
                    Text(done ? "Completed! Come back tomorrow" : "\(DayKey.difficulty(for: today).displayName) · New puzzle every day")
                        .font(Theme.rounded(13, .medium))
                        .opacity(0.85)
                }
                .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundColor(.white.opacity(0.7))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xFF7EB0), Color(hex: 0xE84E8A), Color(hex: 0x8B5CF6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
        }
        .buttonStyle(PressableStyle())
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            if let summary = game.classicSummary {
                homeButton(title: "Continue",
                           subtitle: "\(summary.difficulty.displayName) · \(formatTime(summary.elapsed))",
                           icon: "play.fill", prominent: true) {
                    game.continueClassic()
                    onPlay()
                }
            }
            homeButton(title: "New Game", subtitle: nil, icon: "plus", prominent: game.classicSummary == nil) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showDifficulty = true }
            }
        }
    }

    private var monthShort: String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMM")
        return f.string(from: Date()).uppercased()
    }

    private var dayNumber: String {
        String(Calendar.current.component(.day, from: Date()))
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).foregroundColor(Theme.gold)
            Text(value).font(Theme.rounded(16, .bold)).foregroundColor(.white)
            Text(label).font(Theme.rounded(13, .medium)).foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.14)))
    }

    private func homeButton(title: String, subtitle: String?, icon: String, prominent: Bool,
                            action: @escaping () -> Void) -> some View {
        Button {
            SoundManager.shared.play(.button)
            Haptics.impact(.light)
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(prominent ? Theme.accent.opacity(0.12) : .white.opacity(0.15)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.rounded(20, .bold))
                    if let subtitle {
                        Text(subtitle).font(Theme.rounded(13, .medium)).opacity(0.7).monospacedDigit()
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).opacity(0.6)
            }
            .foregroundColor(prominent ? Theme.accentDeep : .white)
            .padding(.horizontal, 16)
            .frame(height: 66)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(prominent ? Color.white : Color.white.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(prominent ? 0 : 0.35), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(prominent ? 0.2 : 0), radius: 14, y: 6)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Difficulty picker

    private var difficultyPanel: some View {
        VStack(spacing: 12) {
            Capsule().fill(Theme.inkSoft.opacity(0.35)).frame(width: 40, height: 5)
            Text("Choose Difficulty")
                .font(Theme.rounded(22, .bold))
                .foregroundColor(Theme.ink)
                .padding(.bottom, 4)
            ForEach(Difficulty.allCases) { d in
                difficultyRow(d)
            }
        }
        .padding(20)
        .padding(.bottom, 12)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Theme.surface)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func difficultyRow(_ d: Difficulty) -> some View {
        Button {
            guard pending == nil else { return }
            SoundManager.shared.play(.button)
            Haptics.impact(.medium)
            pending = d
            game.newGame(d) {
                pending = nil
                showDifficulty = false
                onPlay()
            }
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(d.color)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(d.displayName.prefix(1)))
                            .font(Theme.rounded(20, .heavy))
                            .foregroundColor(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.displayName).font(Theme.rounded(18, .bold)).foregroundColor(Theme.ink)
                    Text(d.subtitle).font(Theme.rounded(13, .medium)).foregroundColor(Theme.inkSoft)
                }
                Spacer()
                if pending == d {
                    ProgressView()
                } else if let best = game.stats.bestTime[d.rawValue] {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("BEST").font(Theme.rounded(10, .bold)).foregroundColor(Theme.inkSoft)
                        Text(formatTime(best)).font(Theme.rounded(15, .bold)).foregroundColor(Theme.ink).monospacedDigit()
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surfaceAlt))
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }

    private func closeSheet() {
        guard pending == nil else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showDifficulty = false }
    }
}

/// Flickering flame with the current day streak.
struct StreakChip: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: streak > 0 ? [Color(hex: 0xFFD23F), Color(hex: 0xFF5A1F)]
                                                          : [.white.opacity(0.6), .white.opacity(0.4)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .scaleEffect(streak > 0 ? 1 + 0.08 * CGFloat(sin(t * 9)) : 1, anchor: .bottom)
                    .rotationEffect(.degrees(streak > 0 ? 4 * sin(t * 5) : 0), anchor: .bottom)
            }
            .frame(width: 20, height: 22)
            Text("\(streak)")
                .font(Theme.rounded(17, .heavy))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(streak == 1 ? "day" : "days")
                .font(Theme.rounded(13, .medium))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Capsule().fill(.white.opacity(0.16)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streak) day streak")
    }
}
