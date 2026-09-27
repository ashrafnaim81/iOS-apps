import Foundation
import SwiftUI
import UIKit

enum GameMode: Equatable {
    case classic
    case daily(String)

    var dayKey: String? {
        if case .daily(let key) = self { return key }
        return nil
    }

    var saveKey: String {
        switch self {
        case .classic: return "savedGame.v1"
        case .daily(let key): return "savedDaily.\(key)"
        }
    }
}

struct WinResult: Equatable {
    let difficulty: Difficulty
    let dayKey: String?
    let time: Int
    let mistakes: Int
    let hints: Int
    let stars: Int
    let isNewBest: Bool
    let streak: Int
    let newAchievements: [Achievement]

    var isDaily: Bool { dayKey != nil }
}

struct SavedSummary: Equatable {
    let difficulty: Difficulty
    let elapsed: Int
}

private struct GameSnapshot: Codable {
    let difficulty: Difficulty
    let givens: [Int]
    let solution: [Int]
    let values: [Int]
    let mistakes: Int
    let hints: Int
    let elapsed: Int
    let notes: [[Int]]?
}

final class GameModel: ObservableObject {
    @Published private(set) var mode: GameMode = .classic
    @Published private(set) var difficulty: Difficulty = .easy
    @Published private(set) var values = [Int](repeating: 0, count: 81)
    @Published private(set) var givens = [Bool](repeating: false, count: 81)
    @Published private(set) var notes = [Set<Int>](repeating: [], count: 81)
    @Published var selected: Int?
    @Published var notesMode = false
    @Published private(set) var mistakes = 0
    @Published private(set) var hintsUsed = 0
    @Published private(set) var elapsed = 0
    @Published private(set) var isSolved = false
    @Published private(set) var isGenerating = false
    @Published private(set) var hasGame = false
    @Published private(set) var isPaused = false
    @Published private(set) var canUndo = false
    @Published private(set) var lastResult: WinResult?
    @Published private(set) var stats = GameStats.load()
    @Published private(set) var classicSummary: SavedSummary?
    @Published private(set) var catMood: CatMood = .idle

    // Per-cell animation triggers; views react when a counter changes.
    @Published private(set) var popTick = [Int](repeating: 0, count: 81)
    @Published private(set) var shakeTick = [Int](repeating: 0, count: 81)
    @Published private(set) var waveTick = [Int](repeating: 0, count: 81)
    private(set) var waveDelay = [Double](repeating: 0, count: 81)
    @Published private(set) var digitDoneTick = [Int](repeating: 0, count: 10)

    private var solution = [Int](repeating: 0, count: 81)
    private var undoStack: [(values: [Int], notes: [Set<Int>])] = []
    private var timer: Timer?
    private var moodReset: DispatchWorkItem?

    init() {
        if let snapshot = GameModel.snapshot(for: .classic) {
            apply(snapshot, mode: .classic)
        }
        refreshClassicSummary()
    }

    func dailyInProgress(_ key: String) -> Bool {
        (mode == .daily(key) && hasGame && !isSolved) || GameModel.snapshot(for: .daily(key)) != nil
    }

    // MARK: - Game lifecycle

    func newGame(_ difficulty: Difficulty, completion: (() -> Void)? = nil) {
        guard !isGenerating else { return }
        save()
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let puzzle = SudokuGenerator.generate(difficulty)
            DispatchQueue.main.async {
                self.start(puzzle, difficulty: difficulty, mode: .classic)
                completion?()
            }
        }
    }

    /// Resumes the saved classic game (it may not be the one currently loaded).
    func continueClassic() {
        guard mode != .classic else { return }
        save()
        if let snapshot = GameModel.snapshot(for: .classic) {
            apply(snapshot, mode: .classic)
        }
    }

    func startDaily(_ key: String, completion: @escaping () -> Void) {
        guard !isGenerating else { return }
        if mode == .daily(key) && hasGame && !isSolved {
            completion()
            return
        }
        save()
        if let snapshot = GameModel.snapshot(for: .daily(key)) {
            apply(snapshot, mode: .daily(key))
            completion()
            return
        }
        isGenerating = true
        let difficulty = DayKey.difficulty(for: key)
        let seed = SplitMix64.seed(from: "sudoku-santai-daily-\(key)")
        DispatchQueue.global(qos: .userInitiated).async {
            let puzzle = SudokuGenerator.generate(difficulty, seed: seed)
            DispatchQueue.main.async {
                self.start(puzzle, difficulty: difficulty, mode: .daily(key))
                completion()
            }
        }
    }

    private func start(_ puzzle: Puzzle, difficulty: Difficulty, mode: GameMode) {
        self.mode = mode
        self.difficulty = difficulty
        solution = puzzle.solution
        values = puzzle.givens
        givens = puzzle.givens.map { $0 != 0 }
        notes = [Set<Int>](repeating: [], count: 81)
        resetSession()
        for i in 0..<81 where givens[i] {
            waveDelay[i] = Double(i / 9 + i % 9) * 0.025
            waveTick[i] += 1
        }
        save()
    }

    private func apply(_ s: GameSnapshot, mode: GameMode) {
        self.mode = mode
        difficulty = s.difficulty
        solution = s.solution
        values = s.values
        givens = s.givens.map { $0 != 0 }
        notes = s.notes?.map { Set($0) } ?? [Set<Int>](repeating: [], count: 81)
        resetSession()
        mistakes = s.mistakes
        hintsUsed = s.hints
        elapsed = s.elapsed
    }

    private func resetSession() {
        selected = nil
        notesMode = false
        mistakes = 0
        hintsUsed = 0
        elapsed = 0
        isSolved = false
        isPaused = false
        lastResult = nil
        undoStack = []
        canUndo = false
        hasGame = true
        isGenerating = false
        catMood = .idle
    }

    // MARK: - Input

    func select(_ index: Int) {
        guard !isPaused, !isSolved else { return }
        if selected != index {
            selected = index
            SoundManager.shared.play(.tap)
            Haptics.selection()
        }
    }

    func toggleNotesMode() {
        notesMode.toggle()
        SoundManager.shared.play(.button)
        Haptics.impact(.light)
    }

    func enter(_ number: Int) {
        guard let i = selected, !isPaused, !isSolved else { return }
        guard !givens[i] else {
            Haptics.notify(.warning)
            return
        }
        if notesMode {
            toggleNote(number, at: i)
            return
        }
        guard values[i] != number else { return }
        pushUndo()
        values[i] = number
        notes[i] = []
        if number == solution[i] {
            removeNote(number, fromPeersOf: i)
            popTick[i] += 1
            SoundManager.shared.play(.place)
            Haptics.impact(.light)
            afterCorrectPlacement(at: i)
        } else {
            mistakes += 1
            shakeTick[i] += 1
            SoundManager.shared.play(.error)
            Haptics.notify(.error)
            react(.oops)
        }
        save()
    }

    private func toggleNote(_ number: Int, at i: Int) {
        guard values[i] == 0 else {
            Haptics.notify(.warning)
            return
        }
        pushUndo()
        if notes[i].contains(number) {
            notes[i].remove(number)
        } else {
            notes[i].insert(number)
        }
        SoundManager.shared.play(.tap)
        Haptics.selection()
        save()
    }

    private func removeNote(_ number: Int, fromPeersOf i: Int) {
        for j in 0..<81 where j != i && isRelated(j, to: i) && notes[j].contains(number) {
            notes[j].remove(number)
        }
    }

    func erase() {
        guard let i = selected, !givens[i], !isPaused, !isSolved else { return }
        guard values[i] != 0 || !notes[i].isEmpty else { return }
        pushUndo()
        if values[i] != 0 {
            values[i] = 0
        } else {
            notes[i] = []
        }
        SoundManager.shared.play(.erase)
        Haptics.impact(.light)
        save()
    }

    func undo() {
        guard !isPaused, !isSolved, let last = undoStack.popLast() else { return }
        let changed = (0..<81).first { values[$0] != last.values[$0] || notes[$0] != last.notes[$0] }
        values = last.values
        notes = last.notes
        canUndo = !undoStack.isEmpty
        if let changed {
            selected = changed
            if values[changed] != 0 { popTick[changed] += 1 }
        }
        SoundManager.shared.play(.erase)
        Haptics.impact(.light)
        save()
    }

    func hint() {
        guard !isPaused, !isSolved else { return }
        var target: Int?
        if let s = selected, !givens[s], values[s] != solution[s] {
            target = s
        } else {
            target = (0..<81).filter { values[$0] != solution[$0] }.randomElement()
        }
        guard let i = target else { return }
        pushUndo()
        values[i] = solution[i]
        notes[i] = []
        removeNote(solution[i], fromPeersOf: i)
        selected = i
        hintsUsed += 1
        popTick[i] += 1
        SoundManager.shared.play(.hint)
        Haptics.impact(.medium)
        afterCorrectPlacement(at: i)
        save()
    }

    func togglePause() {
        guard hasGame, !isSolved else { return }
        isPaused.toggle()
        SoundManager.shared.play(.button)
        Haptics.impact(.light)
    }

    private func pushUndo() {
        undoStack.append((values, notes))
        if undoStack.count > 300 { undoStack.removeFirst() }
        canUndo = true
    }

    // MARK: - Queries

    func isWrong(_ i: Int) -> Bool { values[i] != 0 && values[i] != solution[i] }

    func isRelated(_ i: Int, to s: Int) -> Bool {
        i / 9 == s / 9 || i % 9 == s % 9 || SudokuGenerator.box(of: i) == SudokuGenerator.box(of: s)
    }

    func remaining(_ n: Int) -> Int {
        var placed = 0
        for i in 0..<81 where values[i] == n && solution[i] == n { placed += 1 }
        return 9 - placed
    }

    func isUnlocked(_ achievement: Achievement) -> Bool {
        stats.achievements[achievement.rawValue] != nil
    }

    // MARK: - Completion effects

    private func react(_ mood: CatMood) {
        moodReset?.cancel()
        catMood = mood
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isSolved else { return }
            self.catMood = .idle
        }
        moodReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private func afterCorrectPlacement(at i: Int) {
        if values == solution {
            finish(from: i)
            return
        }
        let r = i / 9, c = i % 9, b = SudokuGenerator.box(of: i)
        let groups: [[Int]] = [
            (0..<9).map { r * 9 + $0 },
            (0..<9).map { $0 * 9 + c },
            (0..<81).filter { SudokuGenerator.box(of: $0) == b },
        ]
        var celebrated = false
        for group in groups where group.allSatisfy({ values[$0] == solution[$0] }) {
            celebrated = true
            wave(group, from: i)
        }
        if celebrated {
            SoundManager.shared.play(.group)
            Haptics.impact(.medium)
            react(.happy)
        }
        let n = values[i]
        if remaining(n) == 0 { digitDoneTick[n] += 1 }
    }

    private func wave(_ cells: [Int], from origin: Int) {
        for j in cells {
            let d = abs(j / 9 - origin / 9) + abs(j % 9 - origin % 9)
            waveDelay[j] = Double(d) * 0.045
            waveTick[j] += 1
        }
    }

    private func finish(from i: Int) {
        isSolved = true
        selected = nil
        notesMode = false
        stopTimer()
        moodReset?.cancel()
        catMood = .dance
        wave(Array(0..<81), from: i)

        let stars: Int
        if mistakes == 0 && hintsUsed == 0 { stars = 3 } else if mistakes + hintsUsed <= 3 { stars = 2 } else { stars = 1 }
        let key = difficulty.rawValue
        let isNewBest = mode == .classic && (stats.bestTime[key].map { elapsed < $0 } ?? true)
        stats.solved[key, default: 0] += 1
        stats.totalStars += stars
        if stars == 3 { stats.flawless += 1 }
        if isNewBest { stats.bestTime[key] = elapsed }
        if let day = mode.dayKey {
            stats.dailyStars[day] = max(stats.dailyStars[day] ?? 0, stars)
        }
        stats.recordPlay(on: DayKey.today())

        let base = WinResult(difficulty: difficulty, dayKey: mode.dayKey, time: elapsed, mistakes: mistakes,
                             hints: hintsUsed, stars: stars, isNewBest: isNewBest,
                             streak: stats.streak, newAchievements: [])
        let context = Achievement.Context(stats: stats, result: base,
                                          hour: Calendar.current.component(.hour, from: Date()))
        let unlocked = Achievement.allCases.filter { !isUnlocked($0) && $0.isEarned(context) }
        let now = Date().timeIntervalSince1970
        for a in unlocked { stats.achievements[a.rawValue] = now }
        stats.save()

        lastResult = WinResult(difficulty: base.difficulty, dayKey: base.dayKey, time: base.time,
                               mistakes: base.mistakes, hints: base.hints, stars: stars,
                               isNewBest: isNewBest, streak: stats.streak, newAchievements: unlocked)
        UserDefaults.standard.removeObject(forKey: mode.saveKey)
        refreshClassicSummary()
        SoundManager.shared.play(.win)
        Haptics.notify(.success)
    }

    // MARK: - Timer

    func setActive(_ active: Bool) {
        if active && hasGame && !isSolved {
            guard timer == nil else { return }
            let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        } else {
            stopTimer()
            save()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard hasGame, !isPaused, !isSolved, !isGenerating else { return }
        elapsed += 1
        if elapsed % 10 == 0 { save() }
    }

    // MARK: - Persistence

    func save() {
        guard hasGame, !isSolved else { return }
        let snapshot = GameSnapshot(difficulty: difficulty,
                                    givens: (0..<81).map { givens[$0] ? solution[$0] : 0 },
                                    solution: solution, values: values,
                                    mistakes: mistakes, hints: hintsUsed, elapsed: elapsed,
                                    notes: notes.map { $0.sorted() })
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: mode.saveKey)
        }
        if mode == .classic { refreshClassicSummary() }
    }

    private func refreshClassicSummary() {
        if mode == .classic {
            classicSummary = hasGame && !isSolved ? SavedSummary(difficulty: difficulty, elapsed: elapsed) : nil
        } else if let s = GameModel.snapshot(for: .classic) {
            classicSummary = SavedSummary(difficulty: s.difficulty, elapsed: s.elapsed)
        } else {
            classicSummary = nil
        }
    }

    private static func snapshot(for mode: GameMode) -> GameSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: mode.saveKey),
              let s = try? JSONDecoder().decode(GameSnapshot.self, from: data),
              s.values.count == 81, s.solution.count == 81, s.givens.count == 81,
              s.notes == nil || s.notes?.count == 81 else { return nil }
        return s
    }
}
