import SwiftUI

struct BoardView: View {
    @ObservedObject var game: GameModel
    @AppStorage(SettingsKey.highlightRelated) private var highlightRelated = true
    @AppStorage(SettingsKey.highlightSame) private var highlightSame = true

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 9
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { c in
                            cellView(r * 9 + c, size: cell)
                        }
                    }
                }
            }
            .overlay(GridLines(thin: Theme.thinLine, thick: Theme.thickLine))
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.thickLine, lineWidth: 2.5)
            )
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: Theme.accentDeep.opacity(0.12), radius: 16, y: 8)
    }

    private func cellView(_ i: Int, size: CGFloat) -> some View {
        let sel = game.selected
        let selectedValue = sel.map { game.values[$0] } ?? 0
        let value = game.values[i]
        return CellView(
            value: value,
            isGiven: game.givens[i],
            isWrong: game.isWrong(i),
            isSelected: sel == i,
            isRelated: highlightRelated && sel.map { game.isRelated(i, to: $0) } == true,
            isSame: highlightSame && selectedValue != 0 && value == selectedValue,
            size: size,
            popTick: game.popTick[i],
            shakeTick: game.shakeTick[i],
            waveTick: game.waveTick[i],
            waveDelay: game.waveDelay[i]
        )
        .contentShape(Rectangle())
        .onTapGesture { game.select(i) }
        .accessibilityElement()
        .accessibilityLabel("Row \(i / 9 + 1), column \(i % 9 + 1), \(value == 0 ? "empty" : "\(value)")")
        .accessibilityAddTraits(.isButton)
    }
}

/// Thin lines between cells and thick lines only on 3×3 box boundaries.
struct GridLines: View {
    let thin: Color
    let thick: Color
    var thinWidth: CGFloat = 1
    var thickWidth: CGFloat = 2.5

    var body: some View {
        Canvas { context, size in
            var thinPath = Path()
            var thickPath = Path()
            for k in 1..<9 {
                let x = size.width * CGFloat(k) / 9
                let y = size.height * CGFloat(k) / 9
                if k % 3 == 0 {
                    thickPath.move(to: CGPoint(x: x, y: 0)); thickPath.addLine(to: CGPoint(x: x, y: size.height))
                    thickPath.move(to: CGPoint(x: 0, y: y)); thickPath.addLine(to: CGPoint(x: size.width, y: y))
                } else {
                    thinPath.move(to: CGPoint(x: x, y: 0)); thinPath.addLine(to: CGPoint(x: x, y: size.height))
                    thinPath.move(to: CGPoint(x: 0, y: y)); thinPath.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            context.stroke(thinPath, with: .color(thin), lineWidth: thinWidth)
            context.stroke(thickPath, with: .color(thick), lineWidth: thickWidth)
        }
        .allowsHitTesting(false)
    }
}

struct CellView: View {
    let value: Int
    let isGiven: Bool
    let isWrong: Bool
    let isSelected: Bool
    let isRelated: Bool
    let isSame: Bool
    let size: CGFloat
    let popTick: Int
    let shakeTick: Int
    let waveTick: Int
    let waveDelay: Double

    @State private var popScale: CGFloat = 1
    @State private var shakes: CGFloat = 0
    @State private var glow: Double = 0

    var body: some View {
        ZStack {
            Rectangle().fill(background)
            Rectangle().fill(Theme.accent.opacity(0.45 * glow))
            if value != 0 {
                Text("\(value)")
                    .font(Theme.rounded(size * 0.56, isGiven ? .semibold : .medium))
                    .foregroundColor(textColor)
                    .scaleEffect(popScale * (1 + 0.15 * glow))
                    .modifier(ShakeEffect(animatableData: shakes))
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .animation(.easeOut(duration: 0.18), value: isRelated)
        .animation(.easeOut(duration: 0.18), value: isSame)
        .onChange(of: popTick) { _ in
            popScale = 0.3
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.5)) { popScale = 1 }
            }
        }
        .onChange(of: shakeTick) { _ in
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        }
        .onChange(of: waveTick) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + waveDelay) {
                withAnimation(.easeOut(duration: 0.16)) { glow = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeIn(duration: 0.5)) { glow = 0 }
                }
            }
        }
    }

    private var background: Color {
        if isSelected { return Theme.selected }
        if isWrong { return Theme.errorBackground }
        if isSame { return Theme.sameNumber }
        if isRelated { return Theme.related }
        return Theme.surface
    }

    private var textColor: Color {
        if isWrong { return Theme.error }
        return isGiven ? Theme.ink : Theme.userDigit
    }
}
