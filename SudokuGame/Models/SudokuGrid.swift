//
//  SudokuGrid.swift
//  SudokuGame
//
//  Model for Sudoku grid and game logic
//

import Foundation

enum Difficulty {
    case easy
    case medium
    case hard

    var cellsToRemove: Int {
        switch self {
        case .easy: return 35
        case .medium: return 45
        case .hard: return 55
        }
    }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

struct Cell: Identifiable {
    let id = UUID()
    var value: Int
    let isInitial: Bool
    var isError: Bool = false
}

class SudokuGrid: ObservableObject {
    @Published var cells: [[Cell]] = []
    @Published var selectedRow: Int?
    @Published var selectedCol: Int?
    @Published var isCompleted: Bool = false
    @Published var mistakes: Int = 0

    private var solution: [[Int]] = []

    init() {
        generateNewGame(difficulty: .easy)
    }

    func generateNewGame(difficulty: Difficulty) {
        // Reset game state
        isCompleted = false
        mistakes = 0
        selectedRow = nil
        selectedCol = nil

        // Generate a complete valid Sudoku grid
        solution = generateCompleteSudoku()

        // Create puzzle by removing numbers
        var puzzle = solution
        removeCells(from: &puzzle, count: difficulty.cellsToRemove)

        // Convert to Cell objects
        cells = []
        for row in 0..<9 {
            var cellRow: [Cell] = []
            for col in 0..<9 {
                let value = puzzle[row][col]
                let cell = Cell(value: value, isInitial: value != 0)
                cellRow.append(cell)
            }
            cells.append(cellRow)
        }
    }

    private func generateCompleteSudoku() -> [[Int]] {
        var grid = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        _ = fillGrid(&grid, row: 0, col: 0)
        return grid
    }

    private func fillGrid(_ grid: inout [[Int]], row: Int, col: Int) -> Bool {
        var newRow = row
        var newCol = col

        if col == 9 {
            newCol = 0
            newRow += 1
            if newRow == 9 {
                return true
            }
        }

        let numbers = Array(1...9).shuffled()

        for num in numbers {
            if isValidPlacement(grid, row: newRow, col: newCol, num: num) {
                grid[newRow][newCol] = num
                if fillGrid(&grid, row: newRow, col: newCol + 1) {
                    return true
                }
                grid[newRow][newCol] = 0
            }
        }

        return false
    }

    private func isValidPlacement(_ grid: [[Int]], row: Int, col: Int, num: Int) -> Bool {
        // Check row
        for c in 0..<9 {
            if grid[row][c] == num {
                return false
            }
        }

        // Check column
        for r in 0..<9 {
            if grid[r][col] == num {
                return false
            }
        }

        // Check 3x3 box
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for r in boxRow..<boxRow + 3 {
            for c in boxCol..<boxCol + 3 {
                if grid[r][c] == num {
                    return false
                }
            }
        }

        return true
    }

    private func removeCells(from grid: inout [[Int]], count: Int) {
        var removed = 0
        var positions = [(Int, Int)]()

        for row in 0..<9 {
            for col in 0..<9 {
                positions.append((row, col))
            }
        }

        positions.shuffle()

        for (row, col) in positions {
            if removed >= count {
                break
            }
            grid[row][col] = 0
            removed += 1
        }
    }

    func selectCell(row: Int, col: Int) {
        if !cells[row][col].isInitial {
            selectedRow = row
            selectedCol = col
        }
    }

    func setNumber(_ number: Int) {
        guard let row = selectedRow, let col = selectedCol else { return }
        guard !cells[row][col].isInitial else { return }

        // Clear error state for all cells
        for r in 0..<9 {
            for c in 0..<9 {
                cells[r][c].isError = false
            }
        }

        if number == 0 {
            cells[row][col].value = 0
        } else {
            cells[row][col].value = number

            // Check if the number is correct
            if solution[row][col] != number {
                cells[row][col].isError = true
                mistakes += 1
            } else {
                // Check if puzzle is completed
                checkCompletion()
            }
        }
    }

    func getHint() {
        guard let row = selectedRow, let col = selectedCol else { return }
        guard !cells[row][col].isInitial else { return }

        cells[row][col].value = solution[row][col]
        cells[row][col].isError = false
        checkCompletion()
    }

    func clearCell() {
        guard let row = selectedRow, let col = selectedCol else { return }
        guard !cells[row][col].isInitial else { return }

        cells[row][col].value = 0
        cells[row][col].isError = false
    }

    private func checkCompletion() {
        for row in 0..<9 {
            for col in 0..<9 {
                if cells[row][col].value == 0 || cells[row][col].value != solution[row][col] {
                    return
                }
            }
        }
        isCompleted = true
    }
}
