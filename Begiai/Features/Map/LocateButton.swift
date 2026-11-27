import BegiaiKit
import CoreLocation
import MapKit
import SwiftUI

struct LocateButton: View {
    @Binding var position: MapCameraPosition
    /// Set when the app may not locate the rider, so the panel can say why.
    @Binding var locationNote: LocationNote?
    /// The panel's height: a Small panel hides the note, so it rises.
    @Binding var panelHeight: PanelHeight
    /// The followed train, which the map lets go when it goes to the rider.
    @Binding var following: TrainState.ID?
    @State private var session: CLServiceSession?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            if let note = LocationNote.current {
                locationNote = note
                // The note is at the top of the panel's list, which a Small panel hides.
                if panelHeight == .peek { panelHeight = .half }
                return
            }
            if session == nil { session = CLServiceSession(authorization: .whenInUse) }
            following = nil
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
