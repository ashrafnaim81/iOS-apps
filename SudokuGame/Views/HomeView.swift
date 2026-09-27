import SwiftUI

struct HomeView: View {
    @ObservedObject var game: GameModel
    let onPlay: () -> Void
    let onShowTutorial: () -> Void

    @State private var showSettings = false
    @State private var showDifficulty = false
    @State private var appear = false
    @State private var breathe = false
    @State private var pending: Difficulty?

    var body: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            FloatingDigitsBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    CircleIconButton(systemName: "gearshape.fill", tint: .white, background: .white.opacity(0.18)) {
                        showSettings = true
                    }
                    .accessibilityLabel("Settings")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                LogoGrid(size: 150)
                    .scaleEffect(breathe ? 1.03 : 0.97)
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                Text("Sudoku Santai")
                    .font(Theme.rounded(40, .heavy))
                    .foregroundColor(.white)
                    .padding(.top, 26)
                Text("Relax. Think. Solve.")
                    .font(Theme.rounded(17, .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 4)

                Spacer()

                statsRow
                    .padding(.bottom, 20)

                VStack(spacing: 12) {
                    if game.hasSavedGame {
                        homeButton(title: "Continue",
                                   subtitle: "\(game.difficulty.displayName) · \(formatTime(game.elapsed))",
                                   icon: "play.fill", prominent: true) {
                            onPlay()
                        }
                    }
                    homeButton(title: "New Game", subtitle: nil, icon: "plus",
                               prominent: !game.hasSavedGame) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { showDifficulty = true }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 28)
                .frame(maxWidth: 480)
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
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statChip(icon: "checkmark.seal.fill", value: "\(game.stats.totalSolved)", label: "Solved")
            statChip(icon: "star.fill", value: "\(game.stats.totalStars)", label: "Stars")
        }
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundColor(Theme.gold)
            Text(value).font(Theme.rounded(17, .bold)).foregroundColor(.white)
            Text(label).font(Theme.rounded(14, .medium)).foregroundColor(.white.opacity(0.75))
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
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
