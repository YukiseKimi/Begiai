import BegiaiKit
import MapKit
import SwiftData
import SwiftUI

struct MapTab: View {
    let store: TimetableStore
    @Environment(\.timeSource) private var time
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var trains = TrainsModel()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var panelHeight: PanelHeight = .half
    @State private var panelTotal: CGFloat = 700
    @State private var filter: LineFilter = .all
    @State private var position: MapCameraPosition = .region(.lithuania)
    @State private var selection: PanelSelection?
    @State private var following = false
    @Environment(\.modelContext) private var modelContext
    @Query private var stars: [Star]
    @Environment(\.linePalette) private var palette

    var body: some View {
        let chosen = chosenTrain
        let timeline = chosen.flatMap { train in store.engine.map { $0.timeline(of: train) } }
        ZStack(alignment: .bottom) {
            TrainsMap(
                store: store, trains: trains, position: $position, selection: $selection, following: $following,
                panelHeight: $panelHeight, bottomInset: store.state == .ready ? panelHeight.points(in: panelTotal) : 0
            )
            if store.state == .ready, let engine = store.engine, let now = trains.now {
                GeometryReader { proxy in
                    LinePanel(height: $panelHeight, total: proxy.size.height) {
                        switch selection {
                        case .train:
                            TrainPage(timeline: timeline, color: color(of: chosen), now: now, following: $following) {
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
                            if !trains.settled.isEmpty {
                                VStack(spacing: 10) {
                                    RunningHeader(count: trains.settled.count)
                                    LineFilterPicker(filter: $filter)
                                        .padding(.horizontal)
                                }
                            }
                        }
                    } content: {
                        switch selection {
                        case .train:
                            if let timeline {
                                StopList(timeline: timeline, color: color(of: chosen))
                            }
                        case .station(let station):
                            LEDBoard(departures: engine.departures(from: station, at: now))
                        case nil:
                            if trains.settled.isEmpty, let first = engine.firstTrain(after: now) {
                                VStack(spacing: 12) {
                                    StaleNote(since: engine.timetable.staleSince(on: ServiceDate(now)))
                                        .padding(.horizontal)
                                    FirstTrainCard(time: first.time, origin: first.origin, destination: first.destination)
                                }
                            } else {
                                lineList(engine: engine, now: now)
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
        .task(id: TrainsRun(ready: store.engine != nil, pace: pace)) {
            guard let engine = store.engine else { return }
            await trains.run(engine: engine, time: time, pace: pace)
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .NSProcessInfoPowerStateDidChange) {
                lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
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

    private func lineList(engine: MotionEngine, now: Date) -> some View {
        let starred = starredNames(.line)
        let lines = engine.lineSummaries(at: now, trains: trains.settled, starred: starred).filter {
            filter.includes($0, starred: starred)
        }
        // The note scrolls with the lines, so at large text sizes it never pushes them off the panel.
        let staleSince = engine.timetable.staleSince(on: ServiceDate(now))
        return List {
            if staleSince != nil {
                StaleNote(since: staleSince)
                    .listRowBackground(Color.clear)
            }
            ForEach(lines) { line in
                LineRow(line: line, starred: starred.contains(line.name)) {
                    toggleStar(.line, name: line.name)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if lines.isEmpty, filter == .starred {
                ContentUnavailableView(.lineNoneStarred, systemImage: "star", description: Text(.lineNoneStarredDetail))
            }
        }
    }

    private func starredNames(_ kind: StarKind) -> Set<String> {
        Set(stars.filter { $0.kind == kind.rawValue }.map(\.name))
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
    MapTab(store: store)
        .task { await store.load(from: Bundle.main.bundleURL.appending(path: "timetable.json")) }
}

private struct TrainsRun: Equatable {
    let ready: Bool
    let pace: TrainsModel.Pace
}

enum PanelSelection: Equatable {
    case train(TrainState.ID)
    case station(Int)
}
