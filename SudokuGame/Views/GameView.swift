import SwiftUI

struct GameView: View {
    @ObservedObject var game: GameModel
    let onHome: () -> Void
    let onDaily: () -> Void

    @AppStorage(SettingsKey.showTimer) private var showTimer = true
    @State private var showSettings = false
    @State private var showWin = false
    @State private var boardIn = false

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height * 1.15
            ZStack {
                Theme.background.ignoresSafeArea()

                if wide {
                    HStack(spacing: 28) {
                        boardArea
                            .frame(maxWidth: min(geo.size.height - 32, 720))
                        VStack(spacing: 18) {
                            header
                            statsBar
                            Spacer(minLength: 0)
                            controls
                            NumberPadView(game: game, columns: 3)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: 360)
                    }
                    .padding(24)
                } else {
                    VStack(spacing: 14) {
                        header
                        statsBar
                        boardArea
                        controls
                        NumberPadView(game: game)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }

                if showWin, let result = game.lastResult {
                    WinView(result: result, onNext: nextPuzzle, onHome: goHome, onCalendar: onDaily)
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView(onShowTutorial: nil) }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) { boardIn = true }
        }
        .onChange(of: game.isSolved) { solved in
            if solved {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    withAnimation(.easeOut(duration: 0.3)) { showWin = true }
                }
            } else {
                showWin = false
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 10) {
            CircleIconButton(systemName: "chevron.left", action: goHome)
                .accessibilityLabel("Home")
            Spacer()
            HStack(spacing: 6) {
                SantaiCat(mood: game.isPaused ? .sleep : game.catMood, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle().fill(game.difficulty.color).frame(width: 8, height: 8)
                        Text(game.difficulty.displayName).font(Theme.rounded(18, .bold)).foregroundColor(Theme.ink)
                    }
                    Text(subtitle).font(Theme.rounded(12, .medium)).foregroundColor(Theme.inkSoft)
                }
            }
            Spacer()
            CircleIconButton(systemName: game.isPaused ? "play.fill" : "pause.fill") { game.togglePause() }
                .accessibilityLabel(game.isPaused ? "Resume" : "Pause")
            CircleIconButton(systemName: "gearshape.fill") { showSettings = true }
                .accessibilityLabel("Settings")
        }
    }

    private var subtitle: String {
        if let day = game.mode.dayKey { return "Daily · \(DayKey.shortLabel(for: day))" }
        return "Sudoku Santai"
    }

    private var statsBar: some View {
        HStack(spacing: 0) {
            statItem(title: "Mistakes", value: "\(game.mistakes)", color: game.mistakes > 0 ? Theme.error : Theme.ink)
            if showTimer {
                statItem(title: "Time", value: formatTime(game.elapsed), color: Theme.ink)
            }
            statItem(title: "Hints", value: "\(game.hintsUsed)", color: Theme.ink)
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased()).font(Theme.rounded(10, .bold)).foregroundColor(Theme.inkSoft)
            Text(value).font(Theme.rounded(17, .bold)).foregroundColor(color).monospacedDigit()
                .animation(.easeOut(duration: 0.2), value: value)
        }
        .frame(maxWidth: .infinity)
    }

    private var boardArea: some View {
        ZStack {
            BoardView(game: game)
                .blur(radius: game.isPaused ? 14 : 0)
                .allowsHitTesting(!game.isPaused)
            if game.isPaused {
                VStack(spacing: 10) {
                    SantaiCat(mood: .sleep, size: 120)
                    Text("Si Santai is napping").font(Theme.rounded(22, .bold)).foregroundColor(Theme.ink)
                    Button {
                        game.togglePause()
                    } label: {
                        Text("Resume")
                            .font(Theme.rounded(17, .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32).padding(.vertical, 12)
                            .background(Capsule().fill(Theme.brandGradient))
                    }
                    .buttonStyle(PressableStyle())
                }
                .transition(.scale.combined(with: .opacity))
            }
            if game.isGenerating {
                ProgressView().scaleEffect(1.4)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: game.isPaused)
        .scaleEffect(boardIn ? 1 : 0.9)
        .opacity(boardIn ? 1 : 0)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            ToolButton(systemName: "arrow.uturn.backward", title: "Undo", enabled: game.canUndo) { game.undo() }
            ToolButton(systemName: "eraser", title: "Erase", enabled: true) { game.erase() }
            ToolButton(systemName: game.notesMode ? "pencil.circle.fill" : "pencil", title: game.notesMode ? "Notes On" : "Notes",
                       enabled: true, isOn: game.notesMode) { game.toggleNotesMode() }
            ToolButton(systemName: "lightbulb.fill", title: "Hint", enabled: true, tint: Color(hex: 0xE0A100)) { game.hint() }
        }
    }

    // MARK: - Actions

    private func goHome() {
        game.save()
        SoundManager.shared.play(.button)
        onHome()
    }

    private func nextPuzzle() {
        withAnimation(.easeOut(duration: 0.25)) { showWin = false }
        game.newGame(game.difficulty)
    }
}

private struct ToolButton: View {
    let systemName: String
    let title: String
    let enabled: Bool
    var tint: Color = Theme.accent
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemName).font(.system(size: 20, weight: .semibold))
                Text(title).font(Theme.rounded(12, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundColor(isOn ? .white : (enabled ? tint : Theme.inkSoft.opacity(0.5)))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.surface))
            )
            .animation(.easeOut(duration: 0.18), value: isOn)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(PressableStyle(scale: 0.9))
        .disabled(!enabled)
    }
}
