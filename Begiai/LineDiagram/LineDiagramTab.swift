import BegiaiKit
import SwiftData
import SwiftUI

struct LineDiagramTab: View {
    let store: TimetableStore
    /// The train or station open in the sheet; RootView holds it, so it knows when a page is open.
    @Binding var selection: PageSelection?
    /// Regular on a wide screen such as the open iPhone Duo, where a page opens in a column.
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if let engine = store.engine {
            Group {
                if #available(iOS 27.1, *), sizeClass == .regular {
                    // On a wide screen the train or station opens in a column over the diagram's
                    // trailing side, as the map's panel does.
                    MapColumn(identifier: A11yID.LineDiagram.column, shows: selection != nil, withinSafeArea: true) {
                        insets in
                        // The diagram stops at its safe area, short of the tab strip on the right
                        // of the open Duo held wide, so the inset is from that safe area's edge.
                        LineDiagramPage(store: store, selection: $selection, tapCloses: selection != nil)
                            .safeAreaPadding(.trailing, insets.trailing)
                    } panel: {
                        if let selection {
                            DiagramSheet(engine: engine, page: selection)
                                // Close clears the page open in the column.
                                .environment(\.pageClose, .selection($selection))
                                // A new train or station starts its page afresh, as a new sheet does.
                                .id(selection)
                        }
                    }
                } else {
                    LineDiagramPage(store: store, selection: $selection, tapCloses: false)
                }
            }
            // The sheet holds the page only on a narrow screen: a fold or an unfold moves the page
            // between the sheet and the column, and the dismissed sheet does not close it.
            .sheet(item: $selection[shownIf: !inColumn]) { chosen in
                DiagramSheetContent(engine: engine, page: chosen)
                    .presentationDetents([.medium, .large])
            }
        } else {
            TimetableUnavailable(state: store.state)
        }
    }

    /// True where the page opens in a column rather than a sheet.
    private var inColumn: Bool {
        guard #available(iOS 27.1, *) else { return false }
        return sizeClass == .regular
    }
}

/// Where the Line Diagram keeps the name of the last line the rider looked at; a name stays the
/// same in a new timetable.
private enum ChosenLine {
    static let key = "lineDiagram.line"
}

/// The page in the sheet on a narrow screen: Close dismisses the sheet, which clears the open
/// page, and the content leaves the state that presents it alone.
private struct DiagramSheetContent: View {
    let engine: MotionEngine
    let page: PageSelection
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        DiagramSheet(engine: engine, page: page)
            .environment(\.pageClose, .dismiss(dismiss))
    }
}

/// The Line Diagram, once a second: the chips of the lines, and the chosen line's facts and spine.
private struct LineDiagramPage: View {
    /// The timetable's engine, its revision and the diagram of each line.
    let store: TimetableStore
    @Binding var selection: PageSelection?
    /// True where a tap away from the trains and stations closes the open page: in the column,
    /// as a tap on the map closes the map's page. A sheet closes on such a tap by itself.
    let tapCloses: Bool
    @Environment(\.timeSource) private var time
    @AppStorage(ChosenLine.key) private var chosenName = ""
    @Query private var stars: [Star]
    @Environment(\.linePalette) private var palette
    /// The lines this second, the same array while they stay the same.
    @State private var lines: [LineSummary] = []
    /// The chosen line's trains with their places on it, the same array while they stay the same.
    @State private var placed: [SpineTrain] = []
    /// The revision `lines` and `placed` come from: their indices hold in that timetable only.
    @State private var workedOut: Int?
    /// The line `placed` is worked out for: its rows hold on that line's stations only.
    @State private var placedLine: Int?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = time.now
            // Until the lines of a new timetable are worked out, the old ones are not shown.
            let lines = workedOut == store.revision ? lines : []
            let chosen = lines.first { $0.name == chosenName } ?? lines.first
            // A newly chosen line shows no trains until its own are worked out: the rows of
            // the line before may lie past its last station.
            let placed = workedOut == store.revision && placedLine == chosen?.id ? placed : []
            VStack(spacing: 0) {
                LineChips(lines: lines, chosen: chosen?.id)
                    // A scroll view draws its content into the safe area along its axis; the chips
                    // stay in the row's own frame, clear of the status bar and the tab strip that the
                    // open Duo shows on the right.
                    .clipped()
                if let chosen, let engine = store.engine {
                    ScrollView {
                        LineFacts(
                            name: chosen.name, frequency: engine.frequency(of: chosen.id, on: ServiceDate(now)),
                            staleSince: engine.timetable.staleSince(on: ServiceDate(now)))
                        LineSpine(
                            stations: store.diagrams[chosen.id].stations, timetable: engine.timetable,
                            color: palette.color(forLine: chosen.id),
                            trains: placed, selection: $selection)
                    }
                    .contentShape(.rect)
                    .gesture(TapGesture().onEnded { selection = nil }, isEnabled: tapCloses)
                } else {
                    ContentUnavailableView(.diagramNoLines, systemImage: "tram")
                }
            }
            // A line's star changes on the map's tab; the lines take it at their next second,
            // which comes as soon as this tab shows again.
            .onChange(of: DiagramMoment(revision: store.revision, now: now), initial: true) {
                update(at: now)
            }
            .onChange(of: chosenName) {
                update(at: now)
            }
        }
    }

    /// Works out the lines and the chosen line's trains, and keeps each that is the same as
    /// before, so the chips and the spine get the same array and compare it cheaply.
    private func update(at now: Date) {
        guard let engine = store.engine else { return }
        let trains = engine.trains(at: now)
        let latest = engine.lineSummaries(at: now, trains: trains, starred: stars.names(.line))
        if latest != lines { lines = latest }
        let line = (latest.first { $0.name == chosenName } ?? latest.first)?.id
        let diagram = line.map { store.diagrams[$0] }
        let latestPlaced =
            diagram.map { diagram in
                trains.compactMap { train in diagram.place(of: train).map { SpineTrain(train: train, place: $0) } }
            } ?? []
        if latestPlaced != placed { placed = latestPlaced }
        placedLine = line
        workedOut = store.revision
    }
}

/// What the diagram's lines and trains are worked out again for: a new second, or a new
/// timetable.
private struct DiagramMoment: Equatable {
    let revision: Int
    let now: Date
}

/// The chosen line's name, how often its trains leave, and the notes on what the diagram shows.
private struct LineFacts: View {
    let name: String
    let frequency: LineFrequency
    /// `Timetable.staleSince(on:)`, for the note on an old timetable.
    let staleSince: ServiceDate?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: name)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(A11yID.LineDiagram.page)
            FrequencyText(frequency: frequency)
            Text(.trainEstimated)
                .font(.footnote)
                .foregroundStyle(.secondary)
            StaleNote(since: staleSince)
            NoticesLink()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

private struct LineChips: View {
    let lines: [LineSummary]
    let chosen: Int?

    var body: some View {
        // A plain stack: a timetable has about twenty lines, and the row scrolls to the chosen one.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(lines) { line in
                    LineChip(line: line.id, name: line.name, isChosen: line.id == chosen)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
            .padding(.vertical, 2)
        }
        .scrollPosition(id: .constant(chosen), anchor: .center)
        .sensoryFeedback(.selection, trigger: chosen)
    }
}

private struct LineChip: View {
    /// The line's index in the timetable, which picks its colour.
    let line: Int
    let name: String
    let isChosen: Bool
    @AppStorage(ChosenLine.key) private var chosenName = ""
    @Environment(\.linePalette) private var palette

    var body: some View {
        Button {
            chosenName = name
        } label: {
            Text(verbatim: name)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(
                    isChosen
                        ? AnyShapeStyle(ReadableText(background: palette.color(forLine: line)))
                        : AnyShapeStyle(Color.primary)
                )
                .background(isChosen ? palette.color(forLine: line) : Color.secondary.opacity(0.15), in: .capsule)
                // The chip looks small; its tap area is the full 44 points high.
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityIdentifier(A11yID.LineDiagram.chip)
    }
}
