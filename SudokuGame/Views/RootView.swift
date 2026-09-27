import SwiftUI

struct RootView: View {
    private enum Screen { case splash, onboarding, home, game, daily, achievements }

    @StateObject private var game = GameModel()
    @State private var screen: Screen = .splash
    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            switch screen {
            case .splash:
                SplashView { go(hasSeenOnboarding ? .home : .onboarding) }
                    .transition(.opacity)
            case .onboarding:
                OnboardingView {
                    hasSeenOnboarding = true
                    go(.home)
                }
                .transition(.opacity)
            case .home:
                HomeView(game: game,
                         onPlay: { go(.game) },
                         onDaily: { go(.daily) },
                         onAchievements: { go(.achievements) },
                         onShowTutorial: { go(.onboarding) })
                    .transition(.opacity)
            case .game:
                GameView(game: game, onHome: { go(.home) }, onDaily: { go(.daily) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            case .daily:
                DailyView(game: game, onBack: { go(.home) }, onPlay: { go(.game) })
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
            case .achievements:
                AchievementsView(game: game, onBack: { go(.home) })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            }
        }
        .onAppear {
            #if DEBUG
            if let scene = UserDefaults.standard.string(forKey: "screenshot") {
                showScreenshotScene(scene)
                return
            }
            #endif
            MusicManager.shared.refresh()
        }
        .onChange(of: scenePhase) { phase in
            updateActivity()
            if phase == .active {
                MusicManager.shared.refresh()
            } else {
                MusicManager.shared.stop()
            }
        }
        .onChange(of: screen) { next in
            updateActivity()
            MusicManager.shared.play(next == .game ? .game : .home)
        }
    }

    private func go(_ next: Screen) {
        withAnimation(.easeInOut(duration: 0.4)) { screen = next }
    }

    private func updateActivity() {
        game.setActive(scenePhase == .active && screen == .game)
    }

    #if DEBUG
    /// Launch argument `-screenshot <scene>` opens a screen with sample data for App Store screenshots.
    private func showScreenshotScene(_ scene: String) {
        UserDefaults.standard.set(false, forKey: SettingsKey.music)
        UserDefaults.standard.set(false, forKey: SettingsKey.sound)
        hasSeenOnboarding = true
        game.loadScreenshotDemo(solved: scene == "win")
        switch scene {
        case "game", "win": screen = .game
        case "daily": screen = .daily
        case "achievements": screen = .achievements
        case "onboarding": screen = .onboarding
        default: screen = .home
        }
    }
    #endif
}
