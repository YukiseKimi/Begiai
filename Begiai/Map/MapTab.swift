import BegiaiKit
import MapKit
import SwiftData
import SwiftUI

struct MapTab: View {
    let store: TimetableStore
    /// The train or station open in the panel; RootView holds it, so it knows when a page is open.
    @Binding var selection: PanelSelection?
    @Environment(\.timeSource) private var time
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var trains = TrainsModel()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var panelHeight: PanelHeight = .half
    @State private var panelTotal: CGFloat = 700
    @State private var filter: LineFilter = .all
    @State private var position: MapCameraPosition = .region(.lithuania)
    @State private var following = false
    @State private var query = ""
    @State private var locationNote: LocationNote?
    @Environment(\.modelContext) private var modelContext
    @Query private var stars: [Star]
    @Environment(\.linePalette) private var palette

    var body: some View {
        let chosen = chosenTrain
        let timeline = chosen.flatMap { train in store.engine.map { $0.timeline(of: train) } }
        let settled = trains.settled(for: store.revision)
        ZStack(alignment: .bottom) {
            TrainsMap(
                store: store, trains: trains, position: $position, selection: $selection, following: $following,
                panelHeight: $panelHeight, locationNote: $locationNote,
                bottomInset: store.state == .ready ? panelHeight.points(in: panelTotal) : 0
            )
            if store.state == .ready, let engine = store.engine, let now = trains.now {
                GeometryReader { proxy in
                    let station = stationPanel(engine: engine, now: now)
                    LinePanel(height: $panelHeight, total: proxy.size.height) {
                        switch selection {
                        case .train:
                            TrainPage(
                                timeline: timeline, color: color(of: chosen), now: now, following: $following,
                                openStation: { selection = .station($0) }
                            ) {
                                selection = nil
                            }
                        case .station:
                            if let station {
                                station.header
                            }
                        case nil:
                            VStack(spacing: 10) {
                                if !settled.isEmpty {
                                    RunningHeader(count: settled.count)
                                }
                                // At night, with no trains, the field still finds a station's first trains.
                                StationSearchField(query: $query)
                                    .padding(.horizontal)
                                // A Small panel keeps the count and the field; the filter needs room for the lines.
                                if !settled.isEmpty, panelHeight != .peek {
                                    LineFilterPicker(filter: $filter)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    } content: {
                        VStack(spacing: 0) {
                            if let locationNote {
                                LocationNoteView(note: locationNote) { self.locationNote = nil }
                            }
                            switch selection {
                            case .train:
                                if let timeline {
                                    StopList(timeline: timeline, color: color(of: chosen))
                                }
                            case .station:
                                if let station {
                                    station.board
                                }
                            case nil:
                                if searching {
                                    StationResults(names: engine.timetable.stations.map(\.name), query: query) {
                                        selection = .station($0)
                                        if panelHeight == .peek { panelHeight = .half }
                                    }
                                } else if settled.isEmpty, let first = engine.firstTrain(after: now) {
                                    VStack(spacing: 12) {
                                        StaleNote(since: engine.timetable.staleSince(on: ServiceDate(now)))
                                            .padding(.horizontal)
                                        FirstTrainCard(time: first.time, origin: first.origin, destination: first.destination)
                                    }
                                } else {
                                    lineList(engine: engine, running: settled, now: now)
                                }
                            }
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
        .task(id: TrainsRun(revision: store.revision, pace: pace)) {
            guard let engine = store.engine else { return }
            await trains.run(engine: engine, revision: store.revision, time: time, pace: pace)
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Access is granted in Settings, so the note goes when the rider comes back with it.
            if phase == .active, locationNote != nil { locationNote = LocationNote.current }
        }
        .overlay {
            TimetableUnavailable(state: store.state)
        }
    }

    /// The station open in the panel, which gives the panel both its header and its board.
    private func stationPanel(engine: MotionEngine, now: Date) -> StationPanel? {
        guard case .station(let index) = selection, engine.timetable.stations.indices.contains(index) else { return nil }
        let name = engine.timetable.stations[index].name
        return StationPanel(
            index: index, name: name, starred: stars.names(.station).contains(name), engine: engine, now: now
        ) {
            selection = nil
        } toggleStar: {
            toggleStar(.station, name: name)
        }
    }

    /// True while the search field holds more than spaces: its results take the lines' place.
    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The chosen train at the panel's time, worked out from its ID, so that a train that
    /// started less than a second ago has its page at once.
    private var chosenTrain: TrainState? {
        guard case .train(let id) = selection, let engine = store.engine, let now = trains.now else { return nil }
        return engine.train(id, at: now)
    }

    private var pace: TrainsModel.Pace {
        if time.isPinned || scenePhase != .active { return .still }
        if reduceMotion || lowPower || !trains.trainInSight { return .every(.seconds(1)) }
        return .every(trains.frame)
    }

    private func lineList(engine: MotionEngine, running: [TrainState], now: Date) -> some View {
        let starred = stars.names(.line)
        let lines = engine.lineSummaries(at: now, trains: running, starred: starred).filter {
            filter.includes($0, starred: starred)
        }
        // The note scrolls with the lines, so at large text sizes it never pushes them off the panel.
        let staleSince = engine.timetable.staleSince(on: ServiceDate(now))
        let stations = filter == .international ? [] : starredStations(in: engine.timetable)
        return List {
            if staleSince != nil {
                StaleNote(since: staleSince)
                    .listRowBackground(Color.clear)
            }
            if !stations.isEmpty {
                Section {
                    ForEach(stations, id: \.index) { station in
                        StarredStationRow(
                            name: station.name, next: engine.departures(from: station.index, at: now, limit: 1).first, now: now
                        ) {
                            selection = .station(station.index)
                        }
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(.mapYourStations)
                }
            }
            Section {
                ForEach(lines) { line in
                    LineRow(line: line, starred: starred.contains(line.name)) {
                        toggleStar(.line, name: line.name)
                    }
                    .listRowBackground(Color.clear)
                }
            } header: {
                if !stations.isEmpty {
                    Text(.mapLines)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if lines.isEmpty, stations.isEmpty, filter == .starred {
                ContentUnavailableView(.lineNoneStarred, systemImage: "star", description: Text(.lineNoneStarredDetail))
            }
        }
    }

    /// The starred stations that the timetable has, by name.
    private func starredStations(in timetable: Timetable) -> [(index: Int, name: String)] {
        stars.names(.station).sorted().compactMap { name in
            timetable.stations.firstIndex { $0.name == name }.map { ($0, name) }
        }
    }

    private func toggleStar(_ kind: StarKind, name: String) {
        modelContext.toggleStarOrRollBack(kind, name: name, at: time.now)
    }

    private func color(of train: TrainState?) -> Color {
        palette.color(forLine: train.flatMap { store.timetable?.trips[$0.trip].line } ?? 0)
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
    MapTab(store: store, selection: .constant(nil))
        .task { await store.load(from: Bundle.main.bundleURL.appending(path: "timetable.json")) }
}

private struct TrainsRun: Equatable {
    /// The store's timetable revision: a new timetable restarts the trains on its own engine.
    let revision: Int
    let pace: TrainsModel.Pace
}

enum PanelSelection: Equatable {
    case train(TrainState.ID)
    case station(Int)
}
