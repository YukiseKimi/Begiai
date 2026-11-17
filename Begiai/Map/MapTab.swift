import BegiaiKit
import MapKit
import SwiftData
import SwiftUI
import os

struct MapTab: View {
    let store: TimetableStore
    @Environment(\.timeSource) private var time
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cityZoom = false
    @State private var cameraHeading = 0.0
    @State private var panelHeight: PanelHeight = .half
    @State private var panelTotal: CGFloat = 700
    @State private var filter: LineFilter = .all
    @Environment(\.modelContext) private var modelContext
    @Query private var stars: [Star]

    var body: some View {
        TimelineView(
            .animation(minimumInterval: reduceMotion || !cityZoom ? 1 : 1.0 / 30, paused: time.isPinned)
        ) { _ in
            let trains = store.engine?.trains(at: time.now) ?? []
            ZStack(alignment: .bottom) {
                Map(initialPosition: .region(.lithuania)) {
                    ForEach(store.tracks) { track in
                        MapPolyline(coordinates: track.coordinates)
                            .stroke(LinePalette.color(forLine: track.line), lineWidth: 3)
                    }
                    ForEach(trains) { train in
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
                .safeAreaPadding(.bottom, store.state == .ready ? panelHeight.points(in: panelTotal) : 0)
                .ignoresSafeArea()
                if store.state == .ready, let engine = store.engine {
                    GeometryReader { proxy in
                        LinePanel(height: $panelHeight, total: proxy.size.height) {
                            VStack(spacing: 10) {
                                RunningHeader(count: trains.count)
                                LineFilterPicker(filter: $filter)
                                    .padding(.horizontal)
                            }
                        } content: {
                            lineList(engine: engine, trains: trains)
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        panelTotal = $0
                    }
                }
            }
        }
        .overlay {
            if store.state == .loading {
                ProgressView()
            } else if case .failed = store.state {
                ContentUnavailableView(
                    .mapLoadFailed, systemImage: "tram", description: Text(.mapLoadFailedDetail))
            }
        }
    }

    private func lineList(engine: MotionEngine, trains: [TrainState]) -> some View {
        let starred = Set(stars.filter { $0.kind == StarKind.line.rawValue }.map(\.name))
        let lines = engine.lineSummaries(at: time.now, trains: trains, starred: starred).filter {
            filter.includes($0, starred: starred)
        }
        return List(lines) { line in
            LineRow(line: line, starred: starred.contains(line.name)) {
                do {
                    try withAnimation { try modelContext.toggleStar(.line, name: line.name, at: time.now) }
                } catch {
                    modelContext.rollback()
                    Logger(subsystem: "app.begiai.Begiai", category: "stars")
                        .error("A star did not save: \(String(describing: error), privacy: .public)")
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if lines.isEmpty, filter == .starred {
                ContentUnavailableView(.lineNoneStarred, systemImage: "star", description: Text(.lineNoneStarredDetail))
            }
        }
    }

    private func capsule(for train: TrainState) -> some View {
        let trip = store.timetable?.trips[train.trip]
        let destination = trip?.stops.last.flatMap { stop in
            store.timetable?.stations.indices.contains(stop.station) == true
                ? store.timetable?.stations[stop.station].name : nil
        }
        return TrainCapsule(
            color: LinePalette.color(forLine: trip?.line ?? 0), heading: train.heading - cameraHeading,
            destination: destination, atStation: train.phase == .atStation, showsLabel: cityZoom)
    }
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
