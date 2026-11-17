import BegiaiKit
import MapKit
import SwiftUI

struct MapTab: View {
    let store: TimetableStore

    var body: some View {
        Map(initialPosition: .region(.lithuania)) {
            ForEach(store.tracks) { track in
                MapPolyline(coordinates: track.coordinates)
                    .stroke(LinePalette.color(forLine: track.line), lineWidth: 3)
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .overlay {
            if case .failed = store.state {
                ContentUnavailableView(.mapLoadFailed, systemImage: "tram", description: Text(.mapLoadFailedDetail))
            }
        }
        .accessibilityIdentifier(A11yID.Map.page)
    }
}

extension MKCoordinateRegion {
    static let lithuania = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 55.25, longitude: 23.9),
        span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 6.4))
}

#Preview {
    @Previewable @State var store = TimetableStore()
    MapTab(store: store)
        .task {
            if let url = Bundle.main.url(forResource: "timetable", withExtension: "json") {
                await store.load(from: url)
            }
        }
}
