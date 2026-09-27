import SwiftUI

struct NumberPadView: View {
    @ObservedObject var game: GameModel
    var columns = 9

    var body: some View {
        let selectedValue = game.selected.map { game.values[$0] } ?? 0
        let rows = stride(from: 1, through: 9, by: columns).map { Array($0..<min($0 + columns, 10)) }
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { n in
                        NumberKey(number: n,
                                  remaining: game.remaining(n),
                                  doneTick: game.digitDoneTick[n],
                                  isActive: selectedValue == n && !game.notesMode,
                                  notesMode: game.notesMode) {
                            game.enter(n)
                        }
                    }
                }
            }
        }
    }
}

private struct NumberKey: View {
    let number: Int
    let remaining: Int
    let doneTick: Int
    let isActive: Bool
    let notesMode: Bool
    let action: () -> Void

    @State private var bounce: CGFloat = 1

    var body: some View {
        let done = remaining == 0
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(number)")
                    .font(Theme.rounded(notesMode ? 22 : 28, notesMode ? .medium : .semibold))
                    .foregroundColor(isActive ? .white : (notesMode ? Theme.inkSoft : Theme.accent))
                    .frame(height: 30)
                Group {
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                    } else {
                        Text("\(remaining)")
                            .font(Theme.rounded(11, .semibold))
                    }
                }
                .foregroundColor(isActive ? .white.opacity(0.85) : Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(notesMode ? 0.5 : 0),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            )
            .animation(.easeOut(duration: 0.2), value: notesMode)
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            .opacity(done ? 0.4 : 1)
        }
        .buttonStyle(PressableStyle(scale: 0.86))
        .disabled(done)
        .scaleEffect(bounce)
        .animation(.easeOut(duration: 0.15), value: isActive)
        .accessibilityLabel(done ? "\(number), complete" : "\(number), \(remaining) left")
        .onChange(of: doneTick) { _ in
            bounce = 1.35
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.4)) { bounce = 1 }
            }
        }
    }
}
