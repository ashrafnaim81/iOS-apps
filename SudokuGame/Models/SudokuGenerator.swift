import Foundation

struct Puzzle {
    let givens: [Int]
    let solution: [Int]
}

enum SudokuGenerator {
    static func generate(_ difficulty: Difficulty) -> Puzzle {
        let solution = Solver([Int](repeating: 0, count: 81)).randomSolution()
        var puzzle = solution
        var clues = 81
        // Only remove a clue if the puzzle still has exactly one solution,
        // so any correct-by-rules entry always matches the stored solution.
        for index in (0..<81).shuffled() {
            if clues <= difficulty.targetClues { break }
            let saved = puzzle[index]
            puzzle[index] = 0
            if Solver(puzzle).countSolutions(limit: 2) == 1 {
                clues -= 1
            } else {
                puzzle[index] = saved
            }
        }
        return Puzzle(givens: puzzle, solution: solution)
    }

    static func box(of index: Int) -> Int {
        (index / 27) * 3 + (index % 9) / 3
    }
}

private final class Solver {
    private var cells: [Int]
    private var rows = [Int](repeating: 0, count: 9)
    private var cols = [Int](repeating: 0, count: 9)
    private var boxes = [Int](repeating: 0, count: 9)
    private var count = 0
    private var limit = 1
    private var randomize = false

    init(_ cells: [Int]) {
        self.cells = cells
        for i in 0..<81 where cells[i] != 0 {
            mark(i, cells[i], on: true)
        }
    }

    func countSolutions(limit: Int) -> Int {
        self.limit = limit
        randomize = false
        count = 0
        search()
        return count
    }

    func randomSolution() -> [Int] {
        limit = 1
        randomize = true
        count = 0
        search()
        return cells
    }

    private func mark(_ i: Int, _ n: Int, on: Bool) {
        let bit = 1 << n
        let r = i / 9, c = i % 9, b = SudokuGenerator.box(of: i)
        if on {
            rows[r] |= bit; cols[c] |= bit; boxes[b] |= bit
        } else {
            rows[r] &= ~bit; cols[c] &= ~bit; boxes[b] &= ~bit
        }
    }

    // Returns true when the search should stop (limit reached).
    @discardableResult
    private func search() -> Bool {
        var best = -1
        var bestMask = 0
        var bestCount = 10
        for i in 0..<81 where cells[i] == 0 {
            let used = rows[i / 9] | cols[i % 9] | boxes[SudokuGenerator.box(of: i)]
            let available = ~used & 0x3FE
            let n = available.nonzeroBitCount
            if n < bestCount {
                best = i
                bestMask = available
                bestCount = n
                if n <= 1 { break }
            }
        }
        if best == -1 {
            count += 1
            return count >= limit
        }
        if bestCount == 0 { return false }

        var candidates: [Int] = []
        for n in 1...9 where bestMask & (1 << n) != 0 {
            candidates.append(n)
        }
        if randomize { candidates.shuffle() }

        for n in candidates {
            cells[best] = n
            mark(best, n, on: true)
            if search() { return true }
            mark(best, n, on: false)
            cells[best] = 0
        }
        return false
    }
}
