import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Line colours", .sealed, .timeLimit(.minutes(1)))
struct LineColourTests {
    @Test func noTwoLinesThatShareTrackHaveOneColourInTheShippedTimetable() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../Begiai/timetable.json").standardizedFileURL
        let timetable = try JSONDecoder().decode(Timetable.self, from: Data(contentsOf: url))
        let runs = timetable.trackRuns()
        let colours = timetable.lineColours(runs: runs)
        for run in runs where run.lines.count > 1 {
            let used = run.lines.map { colours[$0] }
            #expect(Set(used).count == used.count, "a shared run has lines \(run.lines) with colours \(used)")
        }
    }

    @Test func aLineThatSharesNoTrackStillGetsAColour() {
        let colours = FourStations.timetable.lineColours(runs: [])
        #expect(colours == [0, 0])
    }

    @Test func eachColourCanBeSeenOnItsMap() {
        for colour in LinePaletteRGB.light {
            #expect(Vision.contrast(colour, (1, 1, 1)) >= 3, "\(colour) is too light for the light map")
        }
        for colour in LinePaletteRGB.dark {
            #expect(Vision.contrast(colour, LinePaletteRGB.darkMap) >= 3, "\(colour) is too dark for the dark map")
        }
    }

    @Test(arguments: Vision.allCases)
    func everyTwoColoursStayApart(for vision: Vision) {
        for (name, palette) in [("light", LinePaletteRGB.light), ("dark", LinePaletteRGB.dark)] {
            let seen = palette.map(vision.simulate)
            for i in seen.indices {
                for j in seen.indices where j > i {
                    #expect(Vision.distance(seen[i], seen[j]) >= 30, "\(name) colours \(i) and \(j) look alike for \(vision)")
                }
            }
        }
    }
}

/// How a colour looks to normal, deutan and protan eyes (Machado 2009, full strength), and
/// the CIE76 distance between two colours.
enum Vision: CaseIterable, CustomStringConvertible {
    typealias RGB = (red: Double, green: Double, blue: Double)
    case normal, deutan, protan

    var description: String {
        switch self {
        case .normal: "normal vision"
        case .deutan: "deutan vision"
        case .protan: "protan vision"
        }
    }

    func simulate(_ colour: RGB) -> RGB {
        let matrix: [[Double]] = switch self {
        case .normal: [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
        case .deutan: [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]
        case .protan: [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]
        }
        let linear = [colour.red, colour.green, colour.blue].map(Self.linear)
        let out = matrix.map { row in min(1, max(0, zip(row, linear).map(*).reduce(0, +))) }.map(Self.gamma)
        return (out[0], out[1], out[2])
    }

    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    static func distance(_ a: RGB, _ b: RGB) -> Double {
        let (x, y) = (lab(a), lab(b))
        return ((x.0 - y.0) * (x.0 - y.0) + (x.1 - y.1) * (x.1 - y.1) + (x.2 - y.2) * (x.2 - y.2)).squareRoot()
    }

    private static func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    private static func gamma(_ c: Double) -> Double { c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055 }

    private static func luminance(_ c: RGB) -> Double {
        0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    private static func lab(_ c: RGB) -> (Double, Double, Double) {
        let (r, g, b) = (linear(c.red), linear(c.green), linear(c.blue))
        let x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
        let y = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16 / 116 }
        return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))
    }
}
