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
    @State private var cameraDistance = 400_000.0
    @State private var panelHeight: PanelHeight = .half
    @State private var panelTotal: CGFloat = 700
    @State private var filter: LineFilter = .all
    @State private var position: MapCameraPosition = .region(.lithuania)
    @State private var selection: PanelSelection?
    @State private var following = false
    @Environment(\.modelContext) private var modelContext
    @Query private var stars: [Star]

    var body: some View {
        TimelineView(
            .animation(minimumInterval: reduceMotion || !cityZoom ? 1 : 1.0 / 30, paused: time.isPinned)
        ) { _ in
            let trains = store.engine?.trains(at: time.now) ?? []
            let chosen = trains.first { selection == .train($0.id) }
            let timeline = chosen.flatMap { train in store.engine.map { $0.timeline(of: train) } }
            ZStack(alignment: .bottom) {
                Map(position: $position) {
                    ForEach(store.tracks) { track in
                        MapPolyline(coordinates: track.coordinates)
                            .stroke(LinePalette.color(forLine: track.line), lineWidth: 3)
                    }
                    ForEach(visibleStations, id: \.offset) { station, info in
                        Annotation("", coordinate: info.coordinate.location, anchor: .center) {
                            StationMarker(name: info.name, chosen: selection == .station(station), compact: !cityZoom) {
                                selection = .station(station)
                                if panelHeight == .peek { panelHeight = .half }
                            }
                        }
                        .annotationTitles(.hidden)
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
                    cameraDistance = context.camera.distance
                }
                .onChange(of: FollowTarget(following: following, coordinate: chosen?.coordinate), initial: true) {
                    _, target in
                    guard target.following, let coordinate = target.coordinate else { return }
                    position = .camera(
                        MapCamera(
                            centerCoordinate: coordinate.location, distance: min(cameraDistance, 25_000),
                            heading: cameraHeading))
                }
                .onChange(of: selection) { following = false }
                .onChange(of: position.positionedByUser) { _, byUser in
                    if byUser { following = false }
                }
                .safeAreaPadding(.bottom, store.state == .ready ? panelHeight.points(in: panelTotal) : 0)
                .ignoresSafeArea()
                if store.state == .ready, let engine = store.engine {
                    GeometryReader { proxy in
                        LinePanel(height: $panelHeight, total: proxy.size.height) {
                            switch selection {
                            case .train:
                                TrainPage(timeline: timeline, color: color(of: chosen), now: time.now, following: $following) {
                                    selection = nil
                                }
                            case .station(let station):
                                StationHeader(
                                    name: store.timetable?.stations[station].name ?? "",
                                    starred: starredNames(.station).contains(store.timetable?.stations[station].name ?? "")
                                ) {
                                    selection = nil
                                } toggleStar: {
                                    toggleStar(.station, name: store.timetable?.stations[station].name ?? "")
                                }
                            case nil:
                                VStack(spacing: 10) {
                                    RunningHeader(count: trains.count)
                                    LineFilterPicker(filter: $filter)
                                        .padding(.horizontal)
                                }
                            }
                        } content: {
                            switch selection {
                            case .train:
                                if let timeline {
                                    StopList(timeline: timeline, color: color(of: chosen))
                                }
                            case .station(let station):
                                LEDBoard(departures: engine.departures(from: station, at: time.now))
                            case nil:
                                lineList(engine: engine, trains: trains)
                            }
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
        let starred = starredNames(.line)
        let lines = engine.lineSummaries(at: time.now, trains: trains, starred: starred).filter {
            filter.includes($0, starred: starred)
        }
        return List(lines) { line in
            LineRow(line: line, starred: starred.contains(line.name)) {
                toggleStar(.line, name: line.name)
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

    private var visibleStations: [(offset: Int, element: Station)] {
        guard let timetable = store.timetable else { return [] }
        return timetable.stations.enumerated().filter { station, _ in
            cityZoom || store.bigStations.contains(station) || selection == .station(station)
        }.map { $0 }
    }

    private func starredNames(_ kind: StarKind) -> Set<String> {
        Set(stars.filter { $0.kind == kind.rawValue }.map(\.name))
    }

    private func toggleStar(_ kind: StarKind, name: String) {
        do {
            try withAnimation { try modelContext.toggleStar(kind, name: name, at: time.now) }
        } catch {
            modelContext.rollback()
            Logger(subsystem: "app.begiai.Begiai", category: "stars")
                .error("A star did not save: \(String(describing: error), privacy: .public)")
        }
    }

    private func capsule(for train: TrainState) -> some View {
        let trip = store.timetable?.trips[train.trip]
        let destination = trip?.stops.last.flatMap { stop in
            store.timetable?.stations.indices.contains(stop.station) == true
                ? store.timetable?.stations[stop.station].name : nil
        }
        return Button {
            selection = .train(train.id)
            if panelHeight == .peek { panelHeight = .half }
        } label: {
            TrainCapsule(
                color: color(of: train), heading: train.heading - cameraHeading,
                destination: destination, atStation: train.phase == .atStation, showsLabel: cityZoom,
                chosen: selection == .train(train.id))
        }
        .buttonStyle(.plain)
    }

    private func color(of train: TrainState?) -> Color {
        LinePalette.color(forLine: train.flatMap { store.timetable?.trips[$0.trip].line } ?? 0)
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

private struct FollowTarget: Equatable {
    let following: Bool
    let coordinate: Coordinate?
}

enum PanelSelection: Equatable {
    case train(TrainState.ID)
    case station(Int)
}
