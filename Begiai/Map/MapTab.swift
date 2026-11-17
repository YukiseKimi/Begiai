import BegiaiKit
import MapKit
import SwiftUI

struct MapTab: View {
    let store: TimetableStore
    @Environment(\.timeSource) private var time
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cityZoom = false
    @State private var cameraHeading = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion || !cityZoom ? 1 : 1.0 / 30)) { _ in
            let trains = store.engine?.trains(at: time.now).filter { $0.phase == .running || $0.phase == .atStation } ?? []
            Map(initialPosition: .region(.lithuania)) {
                ForEach(store.tracks) { track in
                    MapPolyline(coordinates: track.coordinates)
                        .stroke(LinePalette.color(forLine: track.line), lineWidth: 3)
                }
                ForEach(trains, id: \.key) { train in
                    Annotation("", coordinate: train.coordinate.location, anchor: .center) {
                        capsule(for: train)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
            .accessibilityIdentifier(A11yID.Map.page)
            .onMapCameraChange { context in
                cityZoom = context.camera.distance < 80_000
                cameraHeading = context.camera.heading
            }
            .safeAreaInset(edge: .top) {
                if store.state == .ready {
                    RunningHeader(count: trains.count)
                }
            }
        }
        .overlay {
            if case .failed = store.state {
                ContentUnavailableView(.mapLoadFailed, systemImage: "tram", description: Text(.mapLoadFailedDetail))
            }
        }
    }

    private func capsule(for train: TrainState) -> some View {
        let trip = store.timetable?.trips[train.trip]
        let destination = trip?.stops.last.flatMap { stop in
            store.timetable?.stations.indices.contains(stop.station) == true ? store.timetable?.stations[stop.station].name : nil
        }
        return TrainCapsule(color: LinePalette.color(forLine: trip?.line ?? 0), heading: train.heading - cameraHeading,
                            destination: destination, atStation: train.phase == .atStation, showsLabel: cityZoom)
    }
}

extension TrainState {
    var key: String { "\(trip)@\(day)" }
}

extension Coordinate {
    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
        .task { await store.load(from: Bundle.main.bundleURL.appending(path: "timetable.json")) }
}
