import Foundation

/// The colour of each line on the map: an index into a palette of `count` colours, given so
/// that no two lines that share a piece of track have the same colour.
extension Timetable {
    /// The colour index of each line, in line order. Lines that share the most track choose
    /// first, and each takes the lowest colour that no line on a shared run has; if all are
    /// taken, it takes the colour that the fewest of its neighbours have.
    public func lineColours(count: Int = LinePaletteRGB.light.count, runs: [TrackRun]? = nil) -> [Int] {
        precondition(count > 0, "a palette needs at least one colour")
        var neighbours = Array(repeating: Set<Int>(), count: lines.count)
        for run in runs ?? trackRuns() where run.lines.count > 1 {
            for a in run.lines { neighbours[a].formUnion(run.lines.filter { $0 != a }) }
        }
        var colour = Array(repeating: -1, count: lines.count)
        // DSatur: the line with the most coloured neighbours goes next, then the most neighbours.
        for _ in lines.indices {
            let next = lines.indices.filter { colour[$0] < 0 }.max { a, b in
                let sa = Set(neighbours[a].map { colour[$0] }.filter { $0 >= 0 }).count
                let sb = Set(neighbours[b].map { colour[$0] }.filter { $0 >= 0 }).count
                return (sa, neighbours[a].count, -a) < (sb, neighbours[b].count, -b)
            }!
            let used = neighbours[next].map { colour[$0] }.filter { $0 >= 0 }
            colour[next] = (0..<count).min { a, b in
                (used.filter { $0 == a }.count, a) < (used.filter { $0 == b }.count, b)
            }!
        }
        return colour
    }
}

/// The map's 8 line colours as sRGB, one pair for each slot. Each light colour has 3:1
/// contrast on a white map, and each dark colour 3:1 on the dark map (#242426). Within each
/// set, every two colours stay at least ΔE 30 apart in normal, deutan and protan vision
/// (checked by LineColourTests). A dark colour keeps the hue of its light colour.
public enum LinePaletteRGB {
    public typealias RGB = (red: Double, green: Double, blue: Double)

    public static let light: [RGB] = [
        (0.77, 0.50, 0.40),
        (0.54, 0.62, 0.01),
        (0.17, 0.34, 0.02),
        (0.11, 0.32, 0.31),
        (0.12, 0.51, 0.99),
        (0.26, 0.21, 0.99),
        (0.52, 0.03, 0.58),
        (0.95, 0.25, 0.63),
    ]

    public static let dark: [RGB] = [
        (0.86, 0.38, 0.08),
        (0.90, 0.93, 0.10),
        (0.64, 0.98, 0.54),
        (0.49, 0.98, 0.81),
        (0.29, 0.44, 0.71),
        (0.75, 0.79, 1.00),
        (0.70, 0.03, 1.00),
        (0.86, 0.20, 0.34),
    ]

    /// The background of the dark map, for the contrast check.
    public static let darkMap: RGB = (0x24 / 255, 0x24 / 255, 0x26 / 255)
}
