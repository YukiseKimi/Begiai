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
    /// Regular on a wide screen such as the open iPhone Duo, where the panel is a column beside the map.
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var trains = TrainsModel()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var panelHeight: PanelHeight = .half
    @State private var panelTotal: CGFloat = 700
    @State private var filter: LineFilter = .all
    @State private var position: MapCameraPosition = .region(.lithuania)
    @State private var following = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var locationNote: LocationNote?
    @Environment(\.modelContext) private var modelContext
    @Query private var stars: [Star]
    @Environment(\.linePalette) private var palette

    var body: some View {
        let chosen = chosenTrain
        let timeline = chosen.flatMap { train in store.engine.map { $0.timeline(of: train) } }
        let settled = trains.settled(for: store.revision)
        Group {
            if #available(iOS 27.1, *), sizeClass == .regular {
                MapColumn { insets in
                    trainsMap(insets: insets)
                } panel: {
                    if store.state == .ready, let engine = store.engine, let now = trains.now {
                        panel(.whole, engine: engine, now: now, settled: settled, timeline: timeline, color: color(of: chosen))
                    }
                }
            } else {
                ZStack(alignment: .bottom) {
                    trainsMap(
                        insets: EdgeInsets(
                            top: 0, leading: 0, bottom: store.state == .ready ? panelHeight.points(in: panelTotal) : 0, trailing: 0))
                    if store.state == .ready, let engine = store.engine, let now = trains.now {
                        GeometryReader { proxy in
                            LinePanel(height: $panelHeight, total: proxy.size.height) {
                                panel(.header, engine: engine, now: now, settled: settled, timeline: timeline, color: color(of: chosen))
                            } content: {
                                panel(.content, engine: engine, now: now, settled: settled, timeline: timeline, color: color(of: chosen))
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
        // The keyboard shows only with the panel at full height. A half panel shows two results above
        // it, and over the map iOS 27.3 loses taps on the right of those rows. So the field raises
        // the panel, and a lower panel, from a drag or a tap on the map, puts the keyboard away.
        .onChange(of: searchFocused) { _, focused in
            if focused { panelHeight = .full }
        }
        .onChange(of: panelHeight) { _, height in
            if height != .full { searchFocused = false }
        }
        .onChange(of: scenePhase) { _, phase in
            // Access is granted in Settings, so the note goes when the rider comes back with it.
            if phase == .active, locationNote != nil { locationNote = LocationNote.current }
        }
        .overlay {
            TimetableUnavailable(state: store.state)
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

    /// The map, keeping `insets` from the screen's edges clear for the panel.
    private func trainsMap(insets: EdgeInsets) -> TrainsMap {
        TrainsMap(
            store: store, trains: trains, position: $position, selection: $selection, following: $following,
            panelHeight: $panelHeight, locationNote: $locationNote, insets: insets)
    }

    private func panel(
        _ part: MapPanel.Part, engine: MotionEngine, now: Date, settled: [TrainState], timeline: TrainTimeline?, color: Color
    ) -> MapPanel {
        MapPanel(
            part: part, engine: engine, now: now, settled: settled, timeline: timeline, color: color,
            selection: $selection, following: $following, height: $panelHeight, filter: $filter, query: $query,
            searchFocused: $searchFocused, locationNote: $locationNote, stars: stars, toggleStar: toggleStar)
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
