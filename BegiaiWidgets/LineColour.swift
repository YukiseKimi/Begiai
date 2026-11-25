import BegiaiKit
import SwiftUI
import UIKit

// Shared by the app and the widget extension, so a line and its times look the same in both.

extension Color {
    /// A line's colour from the palette: its light colour, or its dark colour in Dark Mode.
    init(lineSlot slot: Int) {
        let light = LinePaletteRGB.light[slot % LinePaletteRGB.light.count]
        let dark = LinePaletteRGB.dark[slot % LinePaletteRGB.dark.count]
        self.init(
            UIColor { traits in
                let rgb = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
            })
    }
}

extension Date {
    /// The time in Vilnius, as the timetable gives it, wherever the iPhone is.
    var vilniusTime: String {
        formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: Vilnius.timeZone))
    }
}
