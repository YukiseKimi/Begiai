import BegiaiKit
import SwiftUI
import UIKit

/// The colour of each line. The store gives each line a slot, so that lines that share track
/// never share a colour; views read the palette from the environment. Each slot has a light
/// and a dark colour, picked by the appearance.
struct LinePalette: Equatable {
    static let colors: [Color] = zip(LinePaletteRGB.light, LinePaletteRGB.dark).map { light, dark in
        Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
    }

    /// The slot of each line, by line index. A line with no slot uses its index.
    var slots: [Int] = []

    func color(forLine line: Int) -> Color {
        Self.colors[slot(of: line)]
    }

    /// The colours of the lines in line order, each colour once.
    func colors(forLines lines: [Int]) -> [Color] {
        var seen = Set<Int>()
        return lines.compactMap { line in seen.insert(slot(of: line)).inserted ? Self.colors[slot(of: line)] : nil }
    }

    private func slot(of line: Int) -> Int {
        (slots.indices.contains(line) ? slots[line] : line) % Self.colors.count
    }
}

extension EnvironmentValues {
    @Entry var linePalette = LinePalette()
}

/// Text on a line colour: white or black, whichever has more contrast on that colour in the
/// current appearance. The dark set has light colours, such as yellow, where white is lost.
struct ReadableText: ShapeStyle {
    let background: Color

    func resolve(in environment: EnvironmentValues) -> Color {
        let colour = background.resolve(in: environment)
        let luminance = 0.2126 * Double(colour.linearRed) + 0.7152 * Double(colour.linearGreen) + 0.0722 * Double(colour.linearBlue)
        return 1.05 / (luminance + 0.05) >= (luminance + 0.05) / 0.05 ? .white : .black
    }
}
