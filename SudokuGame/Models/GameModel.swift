import Foundation
import SwiftUI
import UIKit

struct WinResult: Equatable {
    let difficulty: Difficulty
    let time: Int
    let mistakes: Int
    let hints: Int
    let stars: Int
    let isNewBest: Bool
}

private struct GameSnapshot: Codable {
    let difficulty: Difficulty
    let givens: [Int]
    let solution: [Int]
    let values: [Int]
    let mistakes: Int
    let hints: Int
    let elapsed: Int
}

final class GameModel: ObservableObject {
    @Published private(set) var difficulty: Difficulty = .easy
    @Published private(set) var values = [Int](repeating: 0, count: 81)
    @Published private(set) var givens = [Bool](repeating: false, count: 81)
    @Published var selected: Int?
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

    // Per-cell animation triggers; views react when a counter changes.
    @Published private(set) var popTick = [Int](repeating: 0, count: 81)
    @Published private(set) var shakeTick = [Int](repeating: 0, count: 81)
    @Published private(set) var waveTick = [Int](repeating: 0, count: 81)
    private(set) var waveDelay = [Double](repeating: 0, count: 81)
    @Published private(set) var digitDoneTick = [Int](repeating: 0, count: 10)

    private var solution = [Int](repeating: 0, count: 81)
    private var undoStack: [(index: Int, old: Int)] = []
    private var timer: Timer?
    private static let saveKey = "savedGame.v1"

    init() {
        load()
    }

    var hasSavedGame: Bool { hasGame && !isSolved }

    // MARK: - Game lifecycle

    func newGame(_ difficulty: Difficulty, completion: (() -> Void)? = nil) {
        guard !isGenerating else { return }
        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let puzzle = SudokuGenerator.generate(difficulty)
            DispatchQueue.main.async {
                self.start(puzzle, difficulty: difficulty)
                completion?()
            }
        }
    }

    private func start(_ puzzle: Puzzle, difficulty: Difficulty) {
        self.difficulty = difficulty
        solution = puzzle.solution
        values = puzzle.givens
        givens = puzzle.givens.map { $0 != 0 }
        selected = nil
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
        for i in 0..<81 where givens[i] {
            waveDelay[i] = Double(i / 9 + i % 9) * 0.025
            waveTick[i] += 1
        }
        save()
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

    func enter(_ number: Int) {
        guard let i = selected, !isPaused, !isSolved else { return }
        guard !givens[i] else {
            Haptics.notify(.warning)
            return
        }
        guard values[i] != number else { return }
        pushUndo(i)
        values[i] = number
        if number == solution[i] {
            popTick[i] += 1
            SoundManager.shared.play(.place)
            Haptics.impact(.light)
            afterCorrectPlacement(at: i)
        } else {
            mistakes += 1
            shakeTick[i] += 1
            SoundManager.shared.play(.error)
            Haptics.notify(.error)
        }
        save()
    }

    func erase() {
        guard let i = selected, !givens[i], values[i] != 0, !isPaused, !isSolved else { return }
        pushUndo(i)
        values[i] = 0
        SoundManager.shared.play(.erase)
        Haptics.impact(.light)
        save()
    }

    func undo() {
        guard !isPaused, !isSolved, let last = undoStack.popLast() else { return }
        values[last.index] = last.old
        selected = last.index
        canUndo = !undoStack.isEmpty
        if last.old != 0 { popTick[last.index] += 1 }
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
        pushUndo(i)
        values[i] = solution[i]
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

    private func pushUndo(_ index: Int) {
        undoStack.append((index, values[index]))
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

    // MARK: - Completion effects

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
        stopTimer()
        wave(Array(0..<81), from: i)

        let stars: Int
        if mistakes == 0 && hintsUsed == 0 { stars = 3 } else if mistakes + hintsUsed <= 3 { stars = 2 } else { stars = 1 }
        let key = difficulty.rawValue
        let previousBest = stats.bestTime[key]
        let isNewBest = previousBest.map { elapsed < $0 } ?? true
        stats.solved[key, default: 0] += 1
        stats.totalStars += stars
        if isNewBest { stats.bestTime[key] = elapsed }
        stats.save()

        lastResult = WinResult(difficulty: difficulty, time: elapsed, mistakes: mistakes,
                               hints: hintsUsed, stars: stars, isNewBest: isNewBest)
        UserDefaults.standard.removeObject(forKey: GameModel.saveKey)
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
                                    mistakes: mistakes, hints: hintsUsed, elapsed: elapsed)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: GameModel.saveKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: GameModel.saveKey),
              let s = try? JSONDecoder().decode(GameSnapshot.self, from: data),
              s.values.count == 81, s.solution.count == 81, s.givens.count == 81 else { return }
        difficulty = s.difficulty
        solution = s.solution
        values = s.values
        givens = s.givens.map { $0 != 0 }
        mistakes = s.mistakes
        hintsUsed = s.hints
        elapsed = s.elapsed
        hasGame = true
    }
}
