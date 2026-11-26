import BegiaiKit
import SwiftUI

// The map's panel has a header (the count and the search, a train's page or a station's name)
// and a list (the lines, a train's stops or a station's board). The sheet on an iPhone drags by
// its header and scrolls its list, so the two are views of their own; the column on a wide
// screen shows the header above the list.

/// The top of the map's panel: the count and the search, a train's page, or a station's name.
struct MapPanelHeader: View {
    let engine: MotionEngine
    let now: Date
    /// How many trains the map shows, which the header counts.
    let running: Int
    /// The chosen train's stops, and its line's colour.
    let timeline: TrainTimeline?
    let color: Color
    @Binding var selection: PageSelection?
    /// Follow on the train's page: it keeps the train in the middle of the map and on the Lock
    /// Screen; nil hides the button.
    let following: Binding<FollowState>?
    /// True while the followed train's Live Activity shows.
    let onLockScreen: Bool
    /// The sheet's height. The column shows the panel at the last height the sheet had.
    let height: PanelHeight
    @Binding var filter: LineFilter
    let query: StationQuery
    var searchFocused: FocusState<Bool>.Binding
    let stars: [Star]

    var body: some View {
        switch selection {
        case .train:
            TrainPage(
                timeline: timeline, color: color, now: now, following: following, onLockScreen: onLockScreen,
                selection: $selection, stationPage: $selection)
        case .station(let index):
            if engine.timetable.stations.indices.contains(index) {
                let name = engine.stationNames[index]
                StationHeader(name: name, starred: stars.names(.station).contains(name), selection: $selection)
            }
        case nil:
            LinesHeader(running: running, height: height, filter: $filter, query: query, searchFocused: searchFocused)
        }
    }
}

/// The header over the lines: how many trains run, the search field, and the filter.
private struct LinesHeader: View {
    let running: Int
    let height: PanelHeight
    @Binding var filter: LineFilter
    let query: StationQuery
    var searchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 10) {
            if running > 0 {
                // The same margins as the field, so at large text sizes the count and
                // “Scheduled” wrap inside the panel instead of running to its edges.
                // Capped, so at the largest sizes the header leaves the half panel room for lines.
                RunningHeader(count: running)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .padding(.horizontal)
            }
            // At night, with no trains, the field still finds a station's first trains.
            StationSearchField(query: query, focused: searchFocused)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .padding(.horizontal)
            // A Small panel keeps the count and the field; the filter needs room for the lines,
            // and goes while the field searches, as it filters lines, not stations.
            if running > 0, height != .peek, !query.searching {
                LineFilterPicker(filter: $filter)
                    .padding(.horizontal)
            }
        }
    }
}

/// The list of the map's panel: the lines, a train's stops, a station's board, or the stations
/// the search finds, under the note that Locate leaves.
struct MapPanelContent: View {
    let engine: MotionEngine
    let now: Date
    /// The trains on the map, by the second.
    let settled: [TrainState]
    /// The chosen train's stops, and its line's colour.
    let timeline: TrainTimeline?
    let color: Color
    @Binding var selection: PageSelection?
    /// The sheet's height, which a search result lowers.
    @Binding var height: PanelHeight
    let filter: LineFilter
    let query: StationQuery
    @Binding var locationNote: LocationNote?
    let stars: [Star]

    var body: some View {
        VStack(spacing: 0) {
            if let locationNote {
                LocationNoteView(note: locationNote, shown: $locationNote)
            }
            switch selection {
            case .train(let train):
                if let timeline {
                    StopList(train: train, timeline: timeline, color: color)
                }
            case .station(let index):
                if engine.timetable.stations.indices.contains(index) {
                    StationBoard(engine: engine, station: index, now: now)
                }
            case nil:
                if query.searching {
                    StationResults(
                        names: engine.stationNames, calls: engine.callsPerStation, query: query, selection: $selection,
                        height: $height)
                } else if settled.isEmpty, let first = engine.firstTrain(after: now) {
                    VStack(spacing: 12) {
                        StaleNote(since: engine.timetable.staleSince(on: ServiceDate(now)))
                            .padding(.horizontal)
                        FirstTrainCard(time: first.time, origin: first.origin, destination: first.destination)
                    }
                } else {
                    LineList(engine: engine, now: now, settled: settled, filter: filter, stars: stars, selection: $selection)
                }
            }
        }
    }
}

/// The lines with their trains now, under the starred stations with their next trains.
private struct LineList: View {
    let engine: MotionEngine
    let now: Date
    let settled: [TrainState]
    let filter: LineFilter
    let stars: [Star]
    @Binding var selection: PageSelection?

    var body: some View {
        let starred = stars.names(.line)
        let lines = engine.lineSummaries(at: now, trains: settled, starred: starred).filter {
            filter.includes($0, starred: starred)
        }
        // The note scrolls with the lines, so at large text sizes it never pushes them off the panel.
        let staleSince = engine.timetable.staleSince(on: ServiceDate(now))
        let stations = filter == .international ? [] : StarredStation.all(stars.names(.station), engine: engine, now: now)
        List {
            if staleSince != nil {
                StaleNote(since: staleSince)
                    .listRowBackground(Color.clear)
            }
            if !stations.isEmpty {
                Section {
                    ForEach(stations) { station in
                        StarredStationRow(station: station, selection: $selection)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(.mapYourStations)
                }
            }
            Section {
                ForEach(lines) { line in
                    LineRow(line: line, starred: starred.contains(line.name))
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
}
