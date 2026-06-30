import SwiftUI

// A tiny procedural pixel-art companion drawn in a SwiftUI Canvas (no assets). It idles (gentle
// bob + occasional blink) and `celebrate`s after a strong answer (bounce + smile + sparkles).
// `vitality` (0…1) warms it from grey toward a colourful clay tone as the player's creativity grows.
struct PixelCompanion: View {
    var vitality: Double = 0.5
    var celebrate: Bool = false

    // '.' empty, '#' body, 'O' eye, '-' neutral mouth, '^' happy mouth.
    private let idle = [
        "...####...",
        "..######..",
        ".########.",
        "#O####O#.",
        "##########",
        "###----###",
        ".########.",
        "..######..",
        "...#..#...",
    ]
    private let happy = [
        "...####...",
        "..######..",
        ".########.",
        "#O####O#.",
        "##########",
        "##^^^^^^##",
        ".########.",
        "..######..",
        "..#....#..",
    ]

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let rows = celebrate ? happy : idle
                let cols = rows.map(\.count).max() ?? 10
                let cell = min(size.width / CGFloat(cols), size.height / CGFloat(rows.count + 2))
                let gridW = cell * CGFloat(cols), gridH = cell * CGFloat(rows.count)
                let bob = celebrate ? CGFloat(abs(sin(t * 6)) * Double(cell) * 0.8)
                                    : CGFloat(sin(t * 2) * Double(cell) * 0.18)
                let ox = (size.width - gridW) / 2
                let oy = (size.height - gridH) / 2 - bob
                let blink = !celebrate && t.truncatingRemainder(dividingBy: 3.4) < 0.12
                let body = bodyColor()
                let dark = Color.black.opacity(0.6)

                for (r, row) in rows.enumerated() {
                    for (c, ch) in row.enumerated() where ch != "." {
                        let rect = CGRect(x: ox + CGFloat(c) * cell, y: oy + CGFloat(r) * cell,
                                          width: cell + 0.6, height: cell + 0.6)
                        let color: Color = (ch == "O") ? (blink ? body : dark)
                                          : (ch == "-" || ch == "^") ? dark : body
                        ctx.fill(Path(rect), with: .color(color))
                    }
                }
                if celebrate {
                    for i in 0..<6 {
                        let a = t * 2 + Double(i) * .pi / 3
                        let x = size.width / 2 + CGFloat(cos(a)) * gridW * 0.72
                        let y = oy + gridH / 2 + CGFloat(sin(a)) * gridW * 0.72
                        let s = cell * 0.55
                        ctx.fill(Path(CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                                 with: .color(Theme.candle.opacity(0.9)))
                    }
                }
            }
        }
    }

    private func bodyColor() -> Color {
        let v = max(0, min(1, vitality))
        return Color(red: 0.55 + (0.96 - 0.55) * v,
                     green: 0.55 + (0.78 - 0.55) * v,
                     blue: 0.58 + (0.45 - 0.58) * v)
    }
}
