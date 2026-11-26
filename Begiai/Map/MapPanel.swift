import BegiaiKit
import SwiftUI

/// What the map's panel shows: its header (the count and the search, a train's page or a
/// station's name) and its list (the lines, a train's stops or a station's board). The sheet
/// on an iPhone and the column on a wide screen show the same panel.
struct MapPanel: View {
    enum Part {
        /// The part that the sheet's drag moves.
        case header
        case content
        /// The header above the list, as the column shows them.
        case whole
    }

    let part: Part
    let engine: MotionEngine
    let now: Date
    /// The trains on the map that the header counts.
    let settled: [TrainState]
    /// The chosen train's stops, and its line's colour.
    let timeline: TrainTimeline?
    let color: Color
    @Binding var selection: PanelSelection?
    /// Follow on the train's page: it keeps the train in the middle of the map and on the Lock
    /// Screen; nil hides the button.
    let following: Binding<FollowState>?
    /// True while the followed train's Live Activity shows.
    let onLockScreen: Bool
    /// The sheet's height; nil in the column, which has no heights.
    var height: Binding<PanelHeight>?
    @Binding var filter: LineFilter
    @Binding var query: String
    var searchFocused: FocusState<Bool>.Binding
    @Binding var locationNote: LocationNote?
    let stars: [Star]
    let toggleStar: (StarKind, String) -> Void

    var body: some View {
        switch part {
        case .header: header
        case .content: content
        case .whole:
            VStack(spacing: 0) {
                header
                content
            }
        }
    }

    @ViewBuilder private var header: some View {
        switch selection {
        case .train:
            TrainPage(
                timeline: timeline, color: color, now: now, following: following, onLockScreen: onLockScreen,
                openStation: { selection = .station($0) }, close: { selection = nil })
        case .station:
            if let station {
                station.header
            }
        case nil:
            VStack(spacing: 10) {
                if !settled.isEmpty {
                    // The same margins as the field, so at large text sizes the count and
                    // “Scheduled” wrap inside the panel instead of running to its edges.
                    // Capped, so at the largest sizes the header leaves the half panel room for lines.
                    RunningHeader(count: settled.count)
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .padding(.horizontal)
                }
                // At night, with no trains, the field still finds a station's first trains.
                StationSearchField(query: $query, focused: searchFocused)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .padding(.horizontal)
                // A Small panel keeps the count and the field; the filter needs room for the lines,
                // and goes while the field searches, as it filters lines, not stations.
                if !settled.isEmpty, height?.wrappedValue != .peek, !searching {
                    LineFilterPicker(filter: $filter)
                        .padding(.horizontal)
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let locationNote {
                LocationNoteView(note: locationNote) { self.locationNote = nil }
            }
            switch selection {
            case .train:
                if let timeline {
                    StopList(timeline: timeline, color: color)
                }
            case .station:
                if let station {
                    station.board
                }
            case nil:
                if searching {
                    StationResults(
                        names: engine.stationNames, calls: engine.callsPerStation, query: query
                    ) {
                        selection = .station($0)
                        // The search raised the panel; at half height the map shows again beside the board.
                        height?.wrappedValue = .half
                    }
                } else if settled.isEmpty, let first = engine.firstTrain(after: now) {
                    VStack(spacing: 12) {
                        StaleNote(since: engine.timetable.staleSince(on: ServiceDate(now)))
                            .padding(.horizontal)
                        FirstTrainCard(time: first.time, origin: first.origin, destination: first.destination)
                    }
                } else {
                    lineList
                }
            }
        }
    }

    /// The station open in the panel, which gives the panel both its header and its board.
    private var station: StationPanel? {
        guard case .station(let index) = selection, engine.timetable.stations.indices.contains(index) else { return nil }
        let name = engine.timetable.stations[index].name
        return StationPanel(
            index: index, name: name, starred: stars.names(.station).contains(name), engine: engine, now: now
        ) {
            selection = nil
        } toggleStar: {
            toggleStar(.station, name)
        }
    }

    /// True while the search field holds more than spaces: its results take the lines' place.
    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var lineList: some View {
        let starred = stars.names(.line)
        let lines = engine.lineSummaries(at: now, trains: settled, starred: starred).filter {
            filter.includes($0, starred: starred)
        }
        // The note scrolls with the lines, so at large text sizes it never pushes them off the panel.
        let staleSince = engine.timetable.staleSince(on: ServiceDate(now))
        let stations = filter == .international ? [] : starredStations
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
                        toggleStar(.line, line.name)
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
    private var starredStations: [(index: Int, name: String)] {
        stars.names(.station).sorted().compactMap { name in
            engine.timetable.stations.firstIndex { $0.name == name }.map { ($0, name) }
        }
    }
}
