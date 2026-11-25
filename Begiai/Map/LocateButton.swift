import CoreLocation
import MapKit
import SwiftUI

struct LocateButton: View {
    @Binding var position: MapCameraPosition
    /// Called when the app may not locate the rider, so the panel can say why.
    let blocked: (LocationNote) -> Void
    let willLocate: () -> Void
    @State private var session: CLServiceSession?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            if let note = LocationNote.current {
                blocked(note)
                return
            }
            if session == nil { session = CLServiceSession(authorization: .whenInUse) }
            willLocate()
            // With Reduce Motion the map jumps to the rider instead of flying there.
            withAnimation(reduceMotion ? nil : .default) {
                position = .userLocation(fallback: position.followsUserLocation ? .automatic : position)
            }
        } label: {
            MapCircleLabel(systemName: position.followsUserLocation ? "location.fill" : "location")
        }
        .buttonStyle(.plain)
        .glassEffect(in: .circle)
        .accessibilityLabel(Text(.mapLocate))
        .accessibilityShowsLargeContentViewer {
            Label {
                Text(.mapLocate)
            } icon: {
                Image(systemName: "location")
            }
        }
        .accessibilityIdentifier(A11yID.Map.locate)
    }
}

/// The symbol of a round glass button on the map. At the accessibility text sizes the circle
/// would cover the map, so it stops growing at the largest standard size; the button shows
/// itself large on a long press instead, with `accessibilityShowsLargeContentViewer`.
struct MapCircleLabel: View {
    let systemName: String

    var body: some View {
        Circled(systemName: systemName)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private struct Circled: View {
        let systemName: String
        @ScaledMetric(relativeTo: .title3) private var size = 44.0

        var body: some View {
            Image(systemName: systemName)
                .font(.title3)
                .frame(width: size, height: size)
                // A plain button takes taps only on the symbol: the whole circle takes them.
                .contentShape(.circle)
        }
    }
}
