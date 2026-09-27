import Foundation

enum SettingsKey {
    static let sound = "settings.sound"
    static let music = "settings.music"
    static let haptics = "settings.haptics"
    static let highlightRelated = "settings.highlightRelated"
    static let highlightSame = "settings.highlightSame"
    static let showTimer = "settings.showTimer"
    static let hasSeenOnboarding = "hasSeenOnboarding"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            sound: true,
            music: true,
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
    var flawless = 0
    var dailyStars: [String: Int] = [:]
    var streak = 0
    var bestStreak = 0
    var lastPlayDay: String?
    var achievements: [String: Double] = [:]

    private static let key = "stats.v1"

    init() {}

    // Decode field by field so stats saved by older versions keep loading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        solved = try c.decodeIfPresent([String: Int].self, forKey: .solved) ?? [:]
        bestTime = try c.decodeIfPresent([String: Int].self, forKey: .bestTime) ?? [:]
        totalStars = try c.decodeIfPresent(Int.self, forKey: .totalStars) ?? 0
        flawless = try c.decodeIfPresent(Int.self, forKey: .flawless) ?? 0
        dailyStars = try c.decodeIfPresent([String: Int].self, forKey: .dailyStars) ?? [:]
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        bestStreak = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0
        lastPlayDay = try c.decodeIfPresent(String.self, forKey: .lastPlayDay)
        achievements = try c.decodeIfPresent([String: Double].self, forKey: .achievements) ?? [:]
    }

    var totalSolved: Int { solved.values.reduce(0, +) }

    /// The streak is only alive if the player solved something today or yesterday.
    var currentStreak: Int {
        guard let last = lastPlayDay else { return 0 }
        return last == DayKey.today() || last == DayKey.key(daysFromToday: -1) ? streak : 0
    }

    mutating func recordPlay(on day: String) {
        guard lastPlayDay != day else { return }
        streak = lastPlayDay == DayKey.key(daysFromToday: -1) ? streak + 1 : 1
        bestStreak = max(bestStreak, streak)
        lastPlayDay = day
    }

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

/// Calendar days as "yyyy-MM-dd" strings in the player's time zone.
enum DayKey {
    private static var calendar: Calendar { Calendar(identifier: .gregorian) }

    static func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func today() -> String { key(for: Date()) }

    static func key(daysFromToday offset: Int) -> String {
        key(for: calendar.date(byAdding: .day, value: offset, to: Date()) ?? Date())
    }

    static func date(from key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Easier puzzles early in the week, harder ones on Friday and Saturday.
    static func difficulty(for key: String) -> Difficulty {
        guard let date = date(from: key) else { return .medium }
        switch calendar.component(.weekday, from: date) {
        case 2, 3: return .easy
        case 4, 5, 1: return .medium
        default: return .hard
        }
    }

    static func shortLabel(for key: String) -> String {
        guard let date = date(from: key) else { return key }
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f.string(from: date)
    }
}

func formatTime(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
}
