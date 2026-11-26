import Foundation

/// A line's colour as text and symbols on a button that the same colour tints, such as
/// Following on a train's page. The button lays a little of the colour over the panel's glass,
/// where the colour alone can be too light to read, as light green is on the light glass. So
/// the label takes the line's colour made darker in the light look, or lighter in the dark
/// look, just enough for WCAG's 4.5:1 for text.
public enum LineLabel {
    public typealias RGB = LinePaletteRGB.RGB

    /// The panel's glass, as the sheet and the column show it over the map. Darker in the light
    /// look, and lighter in the dark look, than the glass measured in screenshots (luminance
    /// about 0.95 and 0.085), so the label also reads where the map behind the glass differs.
    public static let lightGlass: RGB = (0.90, 0.90, 0.90)
    public static let darkGlass: RGB = (0.33, 0.33, 0.34)

    /// The button's background under its label: the glass with some of the line's colour over
    /// it. A bordered button lays about 18% of its colour over the light glass, and under 10%
    /// over the dark glass, as measured; these shares are a little more than that.
    public static func button(for line: RGB, dark: Bool) -> RGB {
        dark ? mix(darkGlass, line, 0.1) : mix(lightGlass, line, 0.2)
    }

    /// The line's colour, moved towards black in the light look or white in the dark look in
    /// small steps, until it has `contrast` with its button. A colour that reads stays as it is.
    public static func colour(for line: RGB, dark: Bool, contrast: Double = 4.5) -> RGB {
        let button = button(for: line, dark: dark)
        let end: RGB = dark ? (1, 1, 1) : (0, 0, 0)
        let steps = 50
        return (0...steps).lazy.map { mix(line, end, Double($0) / Double(steps)) }
            .first { ratio($0, button) >= contrast } ?? end
    }

    /// WCAG's contrast ratio of two sRGB colours.
    private static func ratio(_ a: RGB, _ b: RGB) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private static func luminance(_ c: RGB) -> Double {
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    }

    private static func mix(_ a: RGB, _ b: RGB, _ amount: Double) -> RGB {
        (a.red + (b.red - a.red) * amount, a.green + (b.green - a.green) * amount, a.blue + (b.blue - a.blue) * amount)
    }
}
