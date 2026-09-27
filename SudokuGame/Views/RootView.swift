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
        .onAppear { MusicManager.shared.refresh() }
        .onChange(of: scenePhase) { phase in
            updateActivity()
            if phase == .active {
                MusicManager.shared.refresh()
            } else {
                MusicManager.shared.stop()
            }
        }
        .onChange(of: screen) { _ in updateActivity() }
    }

    private func go(_ next: Screen) {
        withAnimation(.easeInOut(duration: 0.4)) { screen = next }
    }

    private func updateActivity() {
        game.setActive(scenePhase == .active && screen == .game)
    }
}
