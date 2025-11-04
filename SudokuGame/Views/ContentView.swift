//
//  ContentView.swift
//  SudokuGame
//
//  Main view of the Sudoku game
//

import SwiftUI

struct ContentView: View {
    @StateObject private var game = SudokuGrid()
    @State private var showingDifficultySheet = false
    @State private var showingAbout = false
    @State private var currentDifficulty: Difficulty = .easy

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with stats
                HStack {
                    VStack(alignment: .leading) {
                        Text("Difficulty: \(currentDifficulty.displayName)")
                            .font(.headline)
                        Text("Mistakes: \(game.mistakes)")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // Sudoku Grid
                SudokuGridView(game: game)
                    .padding()

                // Number Pad
                NumberPadView(game: game)
                    .padding(.horizontal)

                // Control Buttons
                HStack(spacing: 15) {
                    Button(action: {
                        game.clearCell()
                    }) {
                        VStack {
                            Image(systemName: "eraser.fill")
                                .font(.title2)
                            Text("Clear")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                    }

                    Button(action: {
                        game.getHint()
                    }) {
                        VStack {
                            Image(systemName: "lightbulb.fill")
                                .font(.title2)
                            Text("Hint")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow.opacity(0.3))
                        .cornerRadius(10)
                    }

                    Button(action: {
                        showingDifficultySheet = true
                    }) {
                        VStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                            Text("New Game")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Sudoku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAbout = true
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingDifficultySheet) {
                DifficultySelectionView(isPresented: $showingDifficultySheet, game: game, currentDifficulty: $currentDifficulty)
            }
            .sheet(isPresented: $showingAbout) {
                AboutView(isPresented: $showingAbout)
            }
            .alert("Congratulations!", isPresented: $game.isCompleted) {
                Button("New Game") {
                    showingDifficultySheet = true
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("You've completed the puzzle with \(game.mistakes) mistake(s)!")
            }
        }
    }
}

struct SudokuGridView: View {
    @ObservedObject var game: SudokuGrid

    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width, geometry.size.height) / 9

            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { col in
                            CellView(
                                cell: game.cells[row][col],
                                isSelected: game.selectedRow == row && game.selectedCol == col,
                                cellSize: cellSize
                            )
                            .onTapGesture {
                                game.selectCell(row: row, col: col)
                            }
                            .border(Color.black, width: col % 3 == 2 && col != 8 ? 2 : 0.5)
                        }
                    }
                    .border(Color.black, width: row % 3 == 2 && row != 8 ? 2 : 0.5)
                }
            }
            .border(Color.black, width: 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct CellView: View {
    let cell: Cell
    let isSelected: Bool
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(backgroundColor)

            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.5, weight: cell.isInitial ? .bold : .regular))
                    .foregroundColor(textColor)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.3)
        } else if cell.isError {
            return Color.red.opacity(0.2)
        } else {
            return Color.white
        }
    }

    private var textColor: Color {
        if cell.isError {
            return .red
        } else if cell.isInitial {
            return .black
        } else {
            return .blue
        }
    }
}

struct NumberPadView: View {
    @ObservedObject var game: SudokuGrid

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...9, id: \.self) { number in
                Button(action: {
                    game.setNumber(number)
                }) {
                    Text("\(number)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
}

struct DifficultySelectionView: View {
    @Binding var isPresented: Bool
    @ObservedObject var game: SudokuGrid
    @Binding var currentDifficulty: Difficulty

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Select Difficulty")) {
                    ForEach([Difficulty.easy, .medium, .hard], id: \.displayName) { difficulty in
                        Button(action: {
                            currentDifficulty = difficulty
                            game.generateNewGame(difficulty: difficulty)
                            isPresented = false
                        }) {
                            HStack {
                                Text(difficulty.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if currentDifficulty.displayName == difficulty.displayName {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct AboutView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Sudoku Game")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Version 1.0")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)

                    VStack(alignment: .leading, spacing: 15) {
                        Text("How to Play")
                            .font(.headline)

                        Text("Fill the 9×9 grid with digits so that each column, each row, and each of the nine 3×3 sub-grids contains all of the digits from 1 to 9.")
                            .font(.body)

                        Text("Features")
                            .font(.headline)
                            .padding(.top)

                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(icon: "star.fill", text: "Three difficulty levels")
                            FeatureRow(icon: "lightbulb.fill", text: "Hint system")
                            FeatureRow(icon: "arrow.clockwise", text: "Unlimited games")
                            FeatureRow(icon: "exclamationmark.triangle.fill", text: "Error detection")
                        }

                        Text("Privacy")
                            .font(.headline)
                            .padding(.top)

                        Text("This app does not collect, store, or share any personal data. All game data is stored locally on your device.")
                            .font(.body)

                        Text("Support")
                            .font(.headline)
                            .padding(.top)

                        Text("Enjoy playing Sudoku! This is a free game with no ads and no in-app purchases.")
                            .font(.body)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.body)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
