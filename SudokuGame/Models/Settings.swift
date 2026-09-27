import Foundation

enum SettingsKey {
    static let sound = "settings.sound"
    static let haptics = "settings.haptics"
    static let highlightRelated = "settings.highlightRelated"
    static let highlightSame = "settings.highlightSame"
    static let showTimer = "settings.showTimer"
    static let hasSeenOnboarding = "hasSeenOnboarding"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            sound: true,
            haptics: true,
            highlightRelated: true,
            highlightSame: true,
            showTimer: true,
        ])
    }
}

struct GameStats: Codable {
    var solved: [String: Int] = [:]
    var bestTime: [String: Int] = [:]
    var totalStars = 0

    private static let key = "stats.v1"

    var totalSolved: Int { solved.values.reduce(0, +) }

    static func load() -> GameStats {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(GameStats.self, from: data) else {
            return GameStats()
        }
        return stats
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: GameStats.key)
        }
    }
}

func formatTime(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}
