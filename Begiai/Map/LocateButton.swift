import CoreLocation
import MapKit
import SwiftUI

struct LocateButton: View {
    @Binding var position: MapCameraPosition
    let willLocate: () -> Void
    @State private var session: CLServiceSession?
    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo: .title3) private var size = 44.0

    var body: some View {
        Button {
            if CLLocationManager().authorizationStatus == .denied {
                if let settings = URL(string: UIApplication.openSettingsURLString) { openURL(settings) }
                return
            }
            if session == nil { session = CLServiceSession(authorization: .whenInUse) }
            willLocate()
            withAnimation { position = .userLocation(fallback: position.followsUserLocation ? .automatic : position) }
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
