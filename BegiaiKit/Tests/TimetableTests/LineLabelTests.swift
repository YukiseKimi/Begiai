import BegiaiKit
import BegiaiKitTestSupport
import Testing

/// A line's colour as text and symbols on a button that the same colour tints, such as Following.
@Suite("Line labels", .sealed, .timeLimit(.minutes(1)))
struct LineLabelTests {
    @Test(arguments: [false, true])
    func eachLineReadsOnItsButton(dark: Bool) {
        for line in dark ? LinePaletteRGB.dark : LinePaletteRGB.light {
            let label = LineLabel.colour(for: line, dark: dark)
            let button = LineLabel.button(for: line, dark: dark)
            #expect(Vision.contrast(label, button) >= 4.5, "\(line) as \(label) on \(button)")
        }
    }

    /// With Increase Contrast a label reads at 7:1, or, where no colour on the button reaches
    /// that, it is white in the dark look and black in the light look.
    @Test(arguments: [false, true])
    func increaseContrastReadsAtSevenToOneOrAsFarAsItCan(dark: Bool) {
        let end: LineLabel.RGB = dark ? (1, 1, 1) : (0, 0, 0)
        for line in dark ? LinePaletteRGB.dark : LinePaletteRGB.light {
            let label = LineLabel.colour(for: line, dark: dark, contrast: 7)
            let button = LineLabel.button(for: line, dark: dark)
            #expect(Vision.contrast(label, button) >= 7 || label == end, "\(line) as \(label) on \(button)")
        }
    }

    /// Light green, Rīga – Vilnius, is too light for text on the light glass: it gets darker.
    /// In the dark look its light green already reads, and stays as it is.
    @Test func aLineColourChangesOnlyWhereItDoesNotRead() {
        let green = LinePaletteRGB.light[1]
        let label = LineLabel.colour(for: green, dark: false)
        #expect(label.red < green.red && label.green < green.green)
        let darkGreen = LinePaletteRGB.dark[1]
        #expect(LineLabel.colour(for: darkGreen, dark: true) == darkGreen)
    }

    @Test func aDarkColourGetsLighterInTheDarkLook() {
        let blue = LinePaletteRGB.dark[4]
        let label = LineLabel.colour(for: blue, dark: true)
        #expect(label.red > blue.red && label.green > blue.green && label.blue >= blue.blue)
    }
}
