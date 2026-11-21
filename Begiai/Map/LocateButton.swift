import CoreLocation
import MapKit
import SwiftUI

struct LocateButton: View {
    @Binding var position: MapCameraPosition
    /// Called when the app may not locate the rider, so the panel can say why.
    let blocked: (LocationNote) -> Void
    let willLocate: () -> Void
    @State private var session: CLServiceSession?
    @ScaledMetric(relativeTo: .title3) private var size = 44.0
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
            Image(systemName: position.followsUserLocation ? "location.fill" : "location")
                .font(.title3)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .glassEffect(in: .circle)
        .accessibilityLabel(Text(.mapLocate))
        .accessibilityIdentifier(A11yID.Map.locate)
    }
}
