import SwiftUI

/// How the trains are drawn: larger, or with a strong outline. Each one is a toggle in About,
/// and high contrast also follows the iOS setting Increase Contrast.
struct MarkerStyle: Equatable {
    var larger = false
    var highContrast = false

    var scale: CGFloat { larger ? 1.4 : 1 }

    static let largerKey = "display.largerMarkers"
    static let highContrastKey = "display.highContrast"
}

extension EnvironmentValues {
    @Entry var markerStyle = MarkerStyle()
}

/// The Display section of About.
struct DisplaySettings: View {
    @AppStorage(MarkerStyle.largerKey) private var larger = false
    @AppStorage(MarkerStyle.highContrastKey) private var highContrast = false
    @Environment(\.colorSchemeContrast) private var systemContrast

    var body: some View {
        Section {
            Toggle(isOn: $larger) {
                Text(.displayLarger)
            }
            .accessibilityIdentifier(A11yID.About.largerMarkers)
            Toggle(isOn: $highContrast) {
                Text(.displayHighContrast)
            }
            .accessibilityIdentifier(A11yID.About.highContrast)
        } header: {
            Text(.displayTitle)
        } footer: {
            if systemContrast == .increased {
                Text(.displayFollowsSystem)
            }
        }
    }
}

extension View {
    /// Gives the views inside the marker style that the rider set in About, with Increase Contrast.
    func markerStyleFromSettings() -> some View {
        modifier(MarkerStyleReader())
    }
}

/// Reads the two settings and the iOS contrast setting, and gives the map its marker style.
private struct MarkerStyleReader: ViewModifier {
    @AppStorage(MarkerStyle.largerKey) private var larger = false
    @AppStorage(MarkerStyle.highContrastKey) private var highContrast = false
    @Environment(\.colorSchemeContrast) private var systemContrast

    func body(content: Content) -> some View {
        content.environment(
            \.markerStyle, MarkerStyle(larger: larger, highContrast: highContrast || systemContrast == .increased))
    }
}
