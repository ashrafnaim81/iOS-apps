import SwiftUI

@main
struct SudokuGameApp: App {
    init() {
        SettingsKey.registerDefaults()
        SoundManager.shared.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
