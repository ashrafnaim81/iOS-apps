import SwiftUI

enum Achievement: String, CaseIterable, Identifiable {
    case firstSolve, flawless, tenSolved, fiftySolved, hundredSolved
    case easyWin, mediumWin, hardWin, expertWin, pureExpert
    case quickEasy, quickMedium, quickHard
    case streak3, streak7, streak30
    case firstDaily, weekOfDailies, nightOwl, earlyBird

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSolve: return "First Steps"
        case .flawless: return "Flawless"
        case .tenSolved: return "Getting Warm"
        case .fiftySolved: return "Puzzle Lover"
        case .hundredSolved: return "Grandmaster"
        case .easyWin: return "Easy Does It"
        case .mediumWin: return "Middle Path"
        case .hardWin: return "Tough Cookie"
        case .expertWin: return "Expert Mind"
        case .pureExpert: return "Pure Genius"
        case .quickEasy: return "Quick Paws"
        case .quickMedium: return "Swift Thinker"
        case .quickHard: return "Lightning"
        case .streak3: return "On a Roll"
        case .streak7: return "Week Warrior"
        case .streak30: return "Unstoppable"
        case .firstDaily: return "Daily Habit"
        case .weekOfDailies: return "Calendar Keeper"
        case .nightOwl: return "Night Owl"
        case .earlyBird: return "Early Bird"
        }
    }

    var detail: String {
        switch self {
        case .firstSolve: return "Solve your first puzzle"
        case .flawless: return "Solve with no mistakes and no hints"
        case .tenSolved: return "Solve 10 puzzles"
        case .fiftySolved: return "Solve 50 puzzles"
        case .hundredSolved: return "Solve 100 puzzles"
        case .easyWin: return "Solve an Easy puzzle"
        case .mediumWin: return "Solve a Medium puzzle"
        case .hardWin: return "Solve a Hard puzzle"
        case .expertWin: return "Solve an Expert puzzle"
        case .pureExpert: return "Flawless Expert solve"
        case .quickEasy: return "Easy in under 5 minutes"
        case .quickMedium: return "Medium in under 10 minutes"
        case .quickHard: return "Hard in under 15 minutes"
        case .streak3: return "Play 3 days in a row"
        case .streak7: return "Play 7 days in a row"
        case .streak30: return "Play 30 days in a row"
        case .firstDaily: return "Complete a Daily Challenge"
        case .weekOfDailies: return "Complete 7 Daily Challenges"
        case .nightOwl: return "Solve between midnight and 5 am"
        case .earlyBird: return "Solve between 5 am and 8 am"
        }
    }

    var icon: String {
        switch self {
        case .firstSolve: return "sparkles"
        case .flawless: return "checkmark.seal.fill"
        case .tenSolved: return "10.circle.fill"
        case .fiftySolved: return "50.circle.fill"
        case .hundredSolved: return "crown.fill"
        case .easyWin: return "leaf.fill"
        case .mediumWin: return "square.grid.3x3.fill"
        case .hardWin: return "shield.fill"
        case .expertWin: return "brain.head.profile"
        case .pureExpert: return "diamond.fill"
        case .quickEasy: return "hare.fill"
        case .quickMedium: return "bolt.fill"
        case .quickHard: return "bolt.circle.fill"
        case .streak3, .streak7, .streak30: return "flame.fill"
        case .firstDaily: return "calendar"
        case .weekOfDailies: return "star.circle.fill"
        case .nightOwl: return "moon.stars.fill"
        case .earlyBird: return "sunrise.fill"
        }
    }

    var color: Color {
        switch self {
        case .firstSolve, .tenSolved, .fiftySolved: return Color(hex: 0x2A7BF6)
        case .hundredSolved, .pureExpert: return Color(hex: 0xE0A100)
        case .flawless, .easyWin: return Color(hex: 0x2FB36E)
        case .mediumWin: return Color(hex: 0x2A7BF6)
        case .hardWin: return Color(hex: 0xF08A24)
        case .expertWin: return Color(hex: 0x8B5CF6)
        case .quickEasy, .quickMedium, .quickHard: return Color(hex: 0x14B8C8)
        case .streak3, .streak7, .streak30: return Color(hex: 0xF0602A)
        case .firstDaily, .weekOfDailies: return Color(hex: 0xE84E8A)
        case .nightOwl: return Color(hex: 0x4B5BD6)
        case .earlyBird: return Color(hex: 0xF5A524)
        }
    }

    struct Context {
        let stats: GameStats
        let result: WinResult
        let hour: Int
    }

    func isEarned(_ c: Context) -> Bool {
        let r = c.result
        switch self {
        case .firstSolve: return c.stats.totalSolved >= 1
        case .flawless: return r.mistakes == 0 && r.hints == 0
        case .tenSolved: return c.stats.totalSolved >= 10
        case .fiftySolved: return c.stats.totalSolved >= 50
        case .hundredSolved: return c.stats.totalSolved >= 100
        case .easyWin: return r.difficulty == .easy
        case .mediumWin: return r.difficulty == .medium
        case .hardWin: return r.difficulty == .hard
        case .expertWin: return r.difficulty == .expert
        case .pureExpert: return r.difficulty == .expert && r.mistakes == 0 && r.hints == 0
        case .quickEasy: return r.difficulty == .easy && r.time < 300
        case .quickMedium: return r.difficulty == .medium && r.time < 600
        case .quickHard: return r.difficulty == .hard && r.time < 900
        case .streak3: return c.stats.streak >= 3
        case .streak7: return c.stats.streak >= 7
        case .streak30: return c.stats.streak >= 30
        case .firstDaily: return r.isDaily
        case .weekOfDailies: return c.stats.dailyStars.count >= 7
        case .nightOwl: return c.hour < 5
        case .earlyBird: return (5..<8).contains(c.hour)
        }
    }
}
