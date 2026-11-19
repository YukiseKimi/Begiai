import SwiftUI

enum LinePalette {
    static let colors: [Color] = [
        Color(red: 0.15, green: 0.39, blue: 0.79),
        Color(red: 0.76, green: 0.25, blue: 0.05),
        Color(red: 0.06, green: 0.54, blue: 0.48),
        Color(red: 0.55, green: 0.25, blue: 0.82),
        Color(red: 0.72, green: 0.20, blue: 0.43),
        Color(red: 0.30, green: 0.49, blue: 0.06),
        Color(red: 0.05, green: 0.45, blue: 0.56),
        Color(red: 0.63, green: 0.38, blue: 0.03),
    ]

    static func color(forLine line: Int) -> Color {
        colors[line % colors.count]
    }

    /// The colours of the lines in line order, each colour once: lines that share a colour
    /// look the same on a shared track.
    static func colors(forLines lines: [Int]) -> [Color] {
        var seen = Set<Int>()
        return lines.compactMap { seen.insert($0 % colors.count).inserted ? color(forLine: $0) : nil }
    }
}
