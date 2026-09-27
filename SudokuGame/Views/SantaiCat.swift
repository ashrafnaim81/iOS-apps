import SwiftUI

enum CatMood: Equatable {
    case idle, happy, oops, sleep, dance, wave
}

/// Si Santai, the ginger cat mascot. Drawn entirely in code on a 100×100 grid
/// so every part (eyes, ears, tail, paws) can move independently.
struct SantaiCat: View {
    var mood: CatMood = .idle
    var size: CGFloat = 120

    @State private var moodStart = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, canvasSize in
                CatRenderer(mood: mood,
                            t: timeline.date.timeIntervalSinceReferenceDate,
                            m: timeline.date.timeIntervalSince(moodStart))
                    .draw(in: context, size: canvasSize)
            }
        }
        .frame(width: size, height: size)
        .onChange(of: mood) { _ in moodStart = Date() }
        .accessibilityHidden(true)
    }
}

private struct CatRenderer {
    let mood: CatMood
    let t: Double
    let m: Double

    private static let fur = Color(hex: 0xF7A24B)
    private static let furDark = Color(hex: 0xD9772A)
    private static let outline = Color(hex: 0xA95A1D)
    private static let cream = Color(hex: 0xFFEBD3)
    private static let pink = Color(hex: 0xFF9CB0)
    private static let ink = Color(hex: 0x3B2A2A)

    // MARK: - Motion

    private var happyAmount: Double { mood == .happy ? max(0, 1 - m / 1.6) : 0 }

    private var bodyOffset: CGFloat {
        switch mood {
        case .happy: return CGFloat(-10 * abs(sin(m * .pi * 2.4)) * happyAmount)
        case .dance: return CGFloat(-6 * abs(sin(t * 4.5)))
        default: return 0
        }
    }

    private var bodyTilt: Double { mood == .dance ? 7 * sin(t * 4.5) : 0 }

    private var headBob: CGFloat {
        let speed = mood == .sleep ? 1.2 : 2.2
        return CGFloat(sin(t * speed) * (mood == .sleep ? 1.3 : 0.8))
    }

    private var headShake: CGFloat {
        mood == .oops ? CGFloat(sin(m * 30) * 1.6 * max(0, 1 - m)) : 0
    }

    private var tailSway: Double {
        switch mood {
        case .dance: return 18 * sin(t * 4.5)
        case .sleep: return 4 * sin(t * 0.8)
        case .happy: return 16 * sin(t * 6)
        default: return 10 * sin(t * 1.6)
        }
    }

    private var eyeOpen: Double {
        t.truncatingRemainder(dividingBy: 3.8) < 0.13 ? 0.12 : 1
    }

    // MARK: - Drawing

    func draw(in context: GraphicsContext, size: CGSize) {
        var ctx = context
        ctx.scaleBy(x: size.width / 100, y: size.height / 100)
        ctx.translateBy(x: 0, y: bodyOffset)
        rotate(&ctx, bodyTilt, around: CGPoint(x: 50, y: 96))

        drawTail(ctx)
        drawBody(ctx)

        var head = ctx
        head.translateBy(x: headShake, y: headBob)
        if mood == .sleep { rotate(&head, 7, around: CGPoint(x: 50, y: 66)) }
        drawEars(head)
        drawHead(head)
        drawFace(head)

        let (left, right) = pawPositions()
        drawPaw(ctx, at: left, shoulder: CGPoint(x: 37, y: 72), big: mood == .oops)
        drawPaw(ctx, at: right, shoulder: CGPoint(x: 63, y: 72), big: mood == .oops)
        drawExtras(ctx)
    }

    private func rotate(_ ctx: inout GraphicsContext, _ degrees: Double, around p: CGPoint) {
        ctx.translateBy(x: p.x, y: p.y)
        ctx.rotate(by: .degrees(degrees))
        ctx.translateBy(x: -p.x, y: -p.y)
    }

    private func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h))
    }

    private func fillOutlined(_ ctx: GraphicsContext, _ path: Path, _ color: Color, width: CGFloat = 1.6) {
        ctx.fill(path, with: .color(color))
        ctx.stroke(path, with: .color(Self.outline), lineWidth: width)
    }

    private func drawTail(_ context: GraphicsContext) {
        var ctx = context
        rotate(&ctx, tailSway, around: CGPoint(x: 66, y: 86))
        var tail = Path()
        tail.move(to: CGPoint(x: 64, y: 88))
        tail.addQuadCurve(to: CGPoint(x: 90, y: 64), control: CGPoint(x: 96, y: 92))
        ctx.stroke(tail, with: .color(Self.outline), style: StrokeStyle(lineWidth: 9.6, lineCap: .round))
        ctx.stroke(tail, with: .color(Self.fur), style: StrokeStyle(lineWidth: 6.4, lineCap: .round))
        ctx.fill(ellipse(86.5, 60.5, 7, 7), with: .color(Self.furDark))
    }

    private func drawBody(_ ctx: GraphicsContext) {
        let breathe = CGFloat(sin(t * (mood == .sleep ? 1.2 : 2.2)) * 0.8)
        fillOutlined(ctx, ellipse(29 - breathe / 2, 60 - breathe, 42 + breathe, 36 + breathe), Self.fur)
        ctx.fill(ellipse(40, 68, 20, 25), with: .color(Self.cream))
        var stripes = Path()
        stripes.move(to: CGPoint(x: 31, y: 76)); stripes.addLine(to: CGPoint(x: 36, y: 77))
        stripes.move(to: CGPoint(x: 69, y: 76)); stripes.addLine(to: CGPoint(x: 64, y: 77))
        ctx.stroke(stripes, with: .color(Self.furDark), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
    }

    private func drawEars(_ ctx: GraphicsContext) {
        let twitch = t.truncatingRemainder(dividingBy: 5.3) < 0.18 ? 5.0 : 0.0
        for side in [-1.0, 1.0] {
            var ear = ctx
            let base = CGPoint(x: 50 + 16 * side, y: 30)
            if side > 0 { rotate(&ear, twitch, around: base) }
            let s = CGFloat(side)
            var outer = Path()
            outer.move(to: CGPoint(x: 50 + 26 * s, y: 38))
            outer.addLine(to: CGPoint(x: 50 + 23 * s, y: 12))
            outer.addLine(to: CGPoint(x: 50 + 5 * s, y: 26))
            outer.closeSubpath()
            fillOutlined(ear, outer, Self.fur)
            var inner = Path()
            inner.move(to: CGPoint(x: 50 + 21 * s, y: 33))
            inner.addLine(to: CGPoint(x: 50 + 20 * s, y: 19))
            inner.addLine(to: CGPoint(x: 50 + 10 * s, y: 27))
            inner.closeSubpath()
            ear.fill(inner, with: .color(Self.pink))
        }
    }

    private func drawHead(_ ctx: GraphicsContext) {
        fillOutlined(ctx, ellipse(20, 24, 60, 46), Self.fur)
        ctx.fill(ellipse(33, 50, 34, 20), with: .color(Self.cream.opacity(0.9)))
        var stripes = Path()
        for (x1, y1, x2, y2) in [(44.0, 27.0, 45.0, 34.0), (50, 25.5, 50, 33.5), (56, 27, 55, 34)] {
            stripes.move(to: CGPoint(x: x1, y: y1))
            stripes.addLine(to: CGPoint(x: x2, y: y2))
        }
        ctx.stroke(stripes, with: .color(Self.furDark), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        ctx.fill(ellipse(25, 51, 10, 6), with: .color(Self.pink.opacity(0.55)))
        ctx.fill(ellipse(65, 51, 10, 6), with: .color(Self.pink.opacity(0.55)))
    }

    private func drawFace(_ ctx: GraphicsContext) {
        let line = StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        for cx in [38.0, 62.0] {
            let c = CGPoint(x: cx, y: 46)
            var arc = Path()
            switch mood {
            case .happy, .dance:
                arc.move(to: CGPoint(x: c.x - 4.5, y: c.y + 2))
                arc.addQuadCurve(to: CGPoint(x: c.x + 4.5, y: c.y + 2), control: CGPoint(x: c.x, y: c.y - 6))
                ctx.stroke(arc, with: .color(Self.ink), style: line)
            case .sleep:
                arc.move(to: CGPoint(x: c.x - 4.5, y: c.y))
                arc.addQuadCurve(to: CGPoint(x: c.x + 4.5, y: c.y), control: CGPoint(x: c.x, y: c.y + 5))
                ctx.stroke(arc, with: .color(Self.ink), style: line)
            case .oops:
                let d: CGFloat = cx < 50 ? 1 : -1
                arc.move(to: CGPoint(x: c.x - 3.5 * d, y: c.y - 3.5))
                arc.addLine(to: CGPoint(x: c.x + 3.5 * d, y: c.y))
                arc.addLine(to: CGPoint(x: c.x - 3.5 * d, y: c.y + 3.5))
                ctx.stroke(arc, with: .color(Self.ink), style: line)
            case .idle, .wave:
                let h = 10.5 * eyeOpen
                ctx.fill(ellipse(c.x - 4.25, c.y - CGFloat(h) / 2, 8.5, CGFloat(h)), with: .color(Self.ink))
                if eyeOpen > 0.5 {
                    ctx.fill(ellipse(c.x - 3.2, c.y - 4, 3.6, 3.6), with: .color(.white))
                    ctx.fill(ellipse(c.x + 0.8, c.y + 1, 1.8, 1.8), with: .color(.white))
                }
            }
        }

        var nose = Path()
        nose.move(to: CGPoint(x: 47.5, y: 53))
        nose.addLine(to: CGPoint(x: 52.5, y: 53))
        nose.addLine(to: CGPoint(x: 50, y: 56))
        nose.closeSubpath()
        ctx.fill(nose, with: .color(Self.pink))
        ctx.stroke(nose, with: .color(Self.outline), style: StrokeStyle(lineWidth: 0.8, lineJoin: .round))

        switch mood {
        case .happy, .dance, .wave:
            var mouth = Path()
            mouth.move(to: CGPoint(x: 45, y: 57.5))
            mouth.addQuadCurve(to: CGPoint(x: 55, y: 57.5), control: CGPoint(x: 50, y: 65.5))
            mouth.closeSubpath()
            ctx.fill(mouth, with: .color(Color(hex: 0x6B2B2B)))
            ctx.fill(ellipse(47.5, 59.6, 5, 2.6), with: .color(Self.pink))
        case .oops:
            ctx.fill(ellipse(48, 57.5, 4, 4.5), with: .color(Color(hex: 0x6B2B2B)))
        case .idle, .sleep:
            var mouth = Path()
            mouth.move(to: CGPoint(x: 45.5, y: 57.5))
            mouth.addQuadCurve(to: CGPoint(x: 50, y: 57.5), control: CGPoint(x: 47.75, y: 61))
            mouth.addQuadCurve(to: CGPoint(x: 54.5, y: 57.5), control: CGPoint(x: 52.25, y: 61))
            ctx.stroke(mouth, with: .color(Self.ink), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        var whiskers = Path()
        for (dy, endX) in [(-3.0, 15.0), (1.5, 14.5), (6.0, 16.0)] {
            whiskers.move(to: CGPoint(x: 31, y: 55)); whiskers.addLine(to: CGPoint(x: endX, y: 55 + dy))
            whiskers.move(to: CGPoint(x: 69, y: 55)); whiskers.addLine(to: CGPoint(x: 100 - endX, y: 55 + dy))
        }
        ctx.stroke(whiskers, with: .color(Self.ink.opacity(0.55)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    private func pawPositions() -> (CGPoint, CGPoint) {
        let restL = CGPoint(x: 39.5, y: 92.5), restR = CGPoint(x: 60.5, y: 92.5)
        func lerp(_ a: CGPoint, _ b: CGPoint, _ k: Double) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * CGFloat(k), y: a.y + (b.y - a.y) * CGFloat(k))
        }
        switch mood {
        case .happy:
            let k = min(1, happyAmount * 2)
            return (lerp(restL, CGPoint(x: 27, y: 62), k), lerp(restR, CGPoint(x: 73, y: 62), k))
        case .oops:
            let k = min(1, m * 5)
            return (lerp(restL, CGPoint(x: 38, y: 46), k), lerp(restR, CGPoint(x: 62, y: 46), k))
        case .dance:
            return (lerp(restL, CGPoint(x: 26, y: 60), max(0, sin(t * 4.5))),
                    lerp(restR, CGPoint(x: 74, y: 60), max(0, -sin(t * 4.5))))
        case .wave:
            let angle = sin(t * 8) * 0.35
            let pivot = CGPoint(x: 66, y: 68), r: CGFloat = 20
            let a = -1.25 + angle
            return (restL, CGPoint(x: pivot.x + r * CGFloat(cos(a)), y: pivot.y + r * CGFloat(sin(a))))
        case .idle, .sleep:
            return (restL, restR)
        }
    }

    private func drawPaw(_ ctx: GraphicsContext, at p: CGPoint, shoulder: CGPoint, big: Bool) {
        if p.y < 84 {
            var arm = Path()
            arm.move(to: shoulder)
            arm.addLine(to: p)
            ctx.stroke(arm, with: .color(Self.outline), style: StrokeStyle(lineWidth: 9.5, lineCap: .round))
            ctx.stroke(arm, with: .color(Self.fur), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
        let w: CGFloat = big ? 15 : 13, h: CGFloat = big ? 12 : 9
        fillOutlined(ctx, ellipse(p.x - w / 2, p.y - h / 2, w, h), Self.cream, width: 1.4)
        var toes = Path()
        toes.move(to: CGPoint(x: p.x - 2, y: p.y + h / 2 - 3)); toes.addLine(to: CGPoint(x: p.x - 2, y: p.y + h / 2 - 1))
        toes.move(to: CGPoint(x: p.x + 2, y: p.y + h / 2 - 3)); toes.addLine(to: CGPoint(x: p.x + 2, y: p.y + h / 2 - 1))
        ctx.stroke(toes, with: .color(Self.outline.opacity(0.7)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }

    private func drawExtras(_ ctx: GraphicsContext) {
        switch mood {
        case .happy:
            let fade = happyAmount
            guard fade > 0 else { return }
            for (i, p) in [CGPoint(x: 12, y: 30), CGPoint(x: 88, y: 26), CGPoint(x: 84, y: 48)].enumerated() {
                sparkle(ctx, at: p, size: CGFloat(5 + 2 * sin(m * 8 + Double(i))), color: Theme.gold, opacity: fade)
            }
        case .dance:
            for i in 0..<3 {
                let a = t * 1.5 + Double(i) * 2.1
                let p = CGPoint(x: 50 + 44 * CGFloat(cos(a)), y: 44 + 30 * CGFloat(sin(a)))
                sparkle(ctx, at: p, size: 5, color: Theme.gold, opacity: 0.9)
            }
        case .oops:
            let drop = CGFloat(min(1, m * 2)) * 6
            var tear = Path()
            tear.move(to: CGPoint(x: 80, y: 24 + drop))
            tear.addQuadCurve(to: CGPoint(x: 80, y: 34 + drop), control: CGPoint(x: 74, y: 32 + drop))
            tear.addQuadCurve(to: CGPoint(x: 80, y: 24 + drop), control: CGPoint(x: 86, y: 32 + drop))
            ctx.fill(tear, with: .color(Color(hex: 0x7CC4FF).opacity(max(0, 1 - m / 2))))
        case .sleep:
            for i in 0..<3 {
                let phase = (t * 0.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                var z = ctx
                z.opacity = sin(phase * .pi)
                z.draw(Text("z").font(.system(size: 8 + CGFloat(i) * 3, weight: .heavy, design: .rounded))
                           .foregroundColor(Color(hex: 0x9DB8FF)),
                       at: CGPoint(x: 74 + 10 * phase, y: 28 - 22 * phase))
            }
        case .idle, .wave:
            break
        }
    }

    private func sparkle(_ ctx: GraphicsContext, at p: CGPoint, size s: CGFloat, color: Color, opacity: Double) {
        var star = Path()
        star.move(to: CGPoint(x: p.x, y: p.y - s))
        star.addQuadCurve(to: CGPoint(x: p.x + s, y: p.y), control: p)
        star.addQuadCurve(to: CGPoint(x: p.x, y: p.y + s), control: p)
        star.addQuadCurve(to: CGPoint(x: p.x - s, y: p.y), control: p)
        star.addQuadCurve(to: CGPoint(x: p.x, y: p.y - s), control: p)
        var c = ctx
        c.opacity = opacity
        c.fill(star, with: .color(color))
    }
}
