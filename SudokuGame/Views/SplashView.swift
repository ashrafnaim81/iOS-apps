import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    @State private var showTitle = false
    @State private var finished = false

    var body: some View {
        ZStack {
            Theme.brandGradient.ignoresSafeArea()
            FloatingDigitsBackground().ignoresSafeArea()
            VStack(spacing: 26) {
                LogoGrid(size: 150)
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                VStack(spacing: 6) {
                    Text("Sudoku Santai")
                        .font(Theme.rounded(38, .heavy))
                    Text("Classic Puzzle")
                        .font(Theme.rounded(16, .semibold))
                        .opacity(0.75)
                }
                .foregroundColor(.white)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 14)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.6)) { showTitle = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { SoundManager.shared.play(.group) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: finish)
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}
