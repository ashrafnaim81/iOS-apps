import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    @State private var showTitle = false
    @State private var showCat = false
    @State private var finished = false

    var body: some View {
        ZStack {
            LivingBackground()
            FloatingDigitsBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                SantaiCat(mood: .wave, size: 140)
                    .padding(.bottom, -32)
                    .zIndex(1)
                    .scaleEffect(showCat ? 1 : 0.3, anchor: .bottom)
                    .opacity(showCat ? 1 : 0)
                LogoGrid(size: 140)
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
                VStack(spacing: 6) {
                    Text("Sudoku Santai")
                        .font(Theme.rounded(38, .heavy))
                    Text("Classic Puzzle")
                        .font(Theme.rounded(16, .semibold))
                        .opacity(0.75)
                }
                .foregroundColor(.white)
                .padding(.top, 24)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 14)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.5)) { showCat = true }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) { showTitle = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { SoundManager.shared.play(.group) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: finish)
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}
