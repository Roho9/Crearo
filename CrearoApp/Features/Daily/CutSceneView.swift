import SwiftUI

// A short pixel cut-scene that acts out the player's idea: the companion conjures the invented item
// (in its colour) and performs the action on the target, ending in a colourful payoff.

enum SceneAction: String {
    case strike, build, transform, summon, fly, grow, give, solve, explore
    static func from(_ s: String) -> SceneAction { SceneAction(rawValue: s.lowercased()) ?? .summon }
    /// Travelling actions send the item across to the target; the rest bloom in place.
    var travels: Bool { self == .strike || self == .fly || self == .give }
}

struct CutSceneView: View {
    let item: String
    let colorName: String
    let action: SceneAction
    let target: String
    let outcome: String
    var onContinue: () -> Void = {}

    @State private var start = Date()
    private let duration: Double = 4.2

    private var color: Color { Self.color(colorName) }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            ZStack {
                LinearGradient(colors: [Theme.sky.opacity(0.25), Theme.berry.opacity(0.18)],
                               startPoint: .top, endPoint: .bottom).ignoresSafeArea()

                Canvas { ctx, size in draw(ctx, size: size, t: t) }

                VStack {
                    if t > 0.4 {
                        Text("“\(item)”").font(Theme.heading).foregroundStyle(color)
                            .padding(.top, 60).transition(.opacity)
                    }
                    Spacer()
                    if t > 2.1 {
                        Text(outcome).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center).padding(.horizontal, 28)
                        Button("Continue") { onContinue() }
                            .font(.headline).foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 14)
                            .background(Theme.ember, in: Capsule())
                            .padding(.bottom, 44).padding(.top, 16)
                    }
                }
            }
            .animation(.easeInOut, value: t > 2.1)
        }
    }

    // MARK: drawing

    private func draw(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let groundY = size.height * 0.6
        let heroC = CGPoint(x: size.width * 0.24, y: groundY)
        let targetC = CGPoint(x: size.width * 0.76, y: groundY)
        let cell = size.width / 44

        // ground line of cheerful pixels
        var gx: CGFloat = 0
        while gx < size.width {
            ctx.fill(Path(CGRect(x: gx, y: groundY + cell * 5, width: cell * 1.6, height: cell * 1.4)),
                     with: .color(Theme.moss.opacity(0.5)))
            gx += cell * 3
        }

        // companion (hero), bobbing
        let bob = CGFloat(sin(t * 6) * Double(cell) * 0.5)
        drawBlob(ctx, center: CGPoint(x: heroC.x, y: heroC.y - bob), cell: cell, color: Theme.sun, eyes: true)

        // target: present until impact, then bursts into confetti
        let impact = t > (action.travels ? 1.7 : 1.9)
        if !impact {
            drawBlob(ctx, center: targetC, cell: cell, color: Theme.fog, eyes: true)
        } else {
            confetti(ctx, center: targetC, cell: cell, t: t - 1.8)
        }

        // the invented item
        let appear = min(1, max(0, (t - 0.3) / 0.5))
        guard appear > 0 else { return }
        if action.travels {
            let travel = min(1, max(0, (t - 0.6) / 1.1))
            let pos = CGPoint(x: heroC.x + (targetC.x - heroC.x) * travel,
                              y: heroC.y - cell * 4 - CGFloat(sin(travel * .pi)) * Double(cell) * 4)
            drawItem(ctx, center: pos, cell: cell * (0.9 + 0.3 * appear), color: color)
        } else {
            // bloom in place between hero and target, growing
            let grow = 0.9 + min(1.8, (t * 0.7)) * 0.9
            let pos = CGPoint(x: size.width / 2, y: groundY - cell * 5)
            drawItem(ctx, center: pos, cell: cell * CGFloat(grow), color: color)
            if t > 1.9 { confetti(ctx, center: pos, cell: cell, t: t - 1.9) }
        }
    }

    private func drawBlob(_ ctx: GraphicsContext, center: CGPoint, cell: CGFloat, color: Color, eyes: Bool) {
        let grid = [".###.", "#####", "#####", "#####", ".###."]
        drawGrid(ctx, grid: grid, center: center, cell: cell, color: color)
        if eyes {
            let dark = Color.black.opacity(0.6)
            ctx.fill(Path(CGRect(x: center.x - cell * 1.4, y: center.y - cell * 0.8, width: cell, height: cell)), with: .color(dark))
            ctx.fill(Path(CGRect(x: center.x + cell * 0.6, y: center.y - cell * 0.8, width: cell, height: cell)), with: .color(dark))
        }
    }

    private func drawItem(_ ctx: GraphicsContext, center: CGPoint, cell: CGFloat, color: Color) {
        let grid = ["..#..", ".###.", "#####", ".###.", "..#.."]  // a little star/gem
        drawGrid(ctx, grid: grid, center: center, cell: cell, color: color)
    }

    private func drawGrid(_ ctx: GraphicsContext, grid: [String], center: CGPoint, cell: CGFloat, color: Color) {
        let rows = grid.count, cols = grid[0].count
        let ox = center.x - CGFloat(cols) / 2 * cell
        let oy = center.y - CGFloat(rows) / 2 * cell
        for (r, row) in grid.enumerated() {
            for (c, ch) in row.enumerated() where ch == "#" {
                ctx.fill(Path(CGRect(x: ox + CGFloat(c) * cell, y: oy + CGFloat(r) * cell,
                                     width: cell + 0.6, height: cell + 0.6)), with: .color(color))
            }
        }
    }

    private func confetti(_ ctx: GraphicsContext, center: CGPoint, cell: CGFloat, t: Double) {
        let n = 18
        for i in 0..<n {
            let a = Double(i) / Double(n) * 2 * .pi
            let speed = 60.0 + Double(i % 5) * 24
            let x = center.x + CGFloat(cos(a) * speed * t)
            let y = center.y + CGFloat(sin(a) * speed * t) + CGFloat(120 * t * t)  // gravity
            let col = Theme.rainbow[i % Theme.rainbow.count]
            ctx.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: .color(col))
        }
    }

    static func color(_ name: String) -> Color {
        let s = name.lowercased()
        if s.contains("red") || s.contains("coral") { return Theme.ember }
        if s.contains("orange") { return Color(red: 1, green: 0.55, blue: 0.2) }
        if s.contains("yellow") || s.contains("gold") || s.contains("sunny") { return Theme.sun }
        if s.contains("green") || s.contains("lime") { return Theme.moss }
        if s.contains("blue") || s.contains("teal") || s.contains("cyan") || s.contains("sky") { return Theme.sky }
        if s.contains("purple") || s.contains("violet") || s.contains("grape") { return Theme.magic }
        if s.contains("pink") || s.contains("rose") || s.contains("magenta") { return Theme.berry }
        if s.contains("white") || s.contains("silver") { return Color(white: 0.82) }
        return Theme.rainbow[abs(name.hashValue) % Theme.rainbow.count]
    }
}
