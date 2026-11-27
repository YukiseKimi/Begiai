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

/// The Line Diagram, once a second: the chips of the lines, and a page for each line with its
/// facts and spine. The pages sit side by side, so a sideways swipe slides to the next line.
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
    /// The lines this second, the same array while they stay the same.
    @State private var lines: [LineSummary] = []
    /// The trains with their places, for the chosen line and the lines beside it, so a page
    /// slides in with its trains. Each line's rows hold on its own stations only.
    @State private var placed: [Int: [SpineTrain]] = [:]
    /// The revision `lines` and `placed` come from: their indices hold in that timetable only.
    @State private var workedOut: Int?
    /// The line of the page in view; it follows the finger, and the chosen line follows it when
    /// the scroll stops.
    @State private var page: Int?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = time.now
            // Until the lines of a new timetable are worked out, the old ones are not shown.
            let current = workedOut == store.revision
            let lines = current ? lines : []
            let chosen = lines.first { $0.name == chosenName } ?? lines.first
            VStack(spacing: 0) {
                LineChips(lines: lines, chosen: chosen?.id)
                    // A scroll view draws its content into the safe area along its axis; the chips
                    // stay in the row's own frame, clear of the status bar and the tab strip that the
                    // open Duo shows on the right.
                    .clipped()
                if let chosen, let engine = store.engine {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            ForEach(lines) { line in
                                LinePage(
                                    line: line, store: store, engine: engine, now: now,
                                    neighbours: Neighbours(of: line, in: lines),
                                    trains: current ? placed[line.id] ?? [] : [], selection: $selection,
                                    tapCloses: tapCloses
                                )
                                .containerRelativeFrame(.horizontal)
                                // Only the chosen line's page is read out and found by the journeys;
                                // the pages beside it are built so that they can slide in.
                                .accessibilityHidden(line.id != chosen.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    // Each page comes to rest at its own edge, one page a swipe. Paging by the scroll
                    // view's width would drift where the scroll view runs under the tab strip that
                    // the Duo shows on the right, and the pages, sized to the visible width, do not.
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .scrollIndicators(.hidden)
                    // As the chips do: the next page does not show under that tab strip.
                    .clipped()
                    .scrollPosition(id: $page)
                    .onScrollPhaseChange { _, phase in
                        // The chosen line changes when the pages come to rest, not on the way.
                        if phase == .idle, let name = lines.first(where: { $0.id == page })?.name, name != chosenName {
                            chosenName = name
                        }
                    }
                    .onChange(of: chosen.id, initial: true) { old, new in
                        // A chip or VoiceOver chose the line: slide to its page.
                        guard page != new else { return }
                        if old == new { page = new } else { withAnimation(.snappy) { page = new } }
                    }
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

    /// Works out the lines and the trains of the chosen line and the lines beside it, and keeps
    /// each that is the same as before, so the chips and the spines get the same arrays and
    /// compare them cheaply.
    private func update(at now: Date) {
        guard let engine = store.engine else { return }
        let trains = engine.trains(at: now)
        let latest = engine.lineSummaries(at: now, trains: trains, starred: stars.names(.line))
        if latest != lines { lines = latest }
        var latestPlaced: [Int: [SpineTrain]] = [:]
        if let index = latest.firstIndex(where: { $0.name == chosenName }) ?? (latest.isEmpty ? nil : 0) {
            for line in latest[max(index - 1, 0)...min(index + 1, latest.count - 1)] {
                let diagram = store.diagrams[line.id]
                latestPlaced[line.id] = trains.compactMap { train in
                    diagram.place(of: train).map { SpineTrain(train: train, place: $0) }
                }
            }
        }
        if latestPlaced != placed { placed = latestPlaced }
        workedOut = store.revision
    }
}

/// One line's page: its facts and its spine, scrolling up and down.
private struct LinePage: View {
    let line: LineSummary
    let store: TimetableStore
    let engine: MotionEngine
    let now: Date
    let neighbours: Neighbours
    let trains: [SpineTrain]
    @Binding var selection: PageSelection?
    let tapCloses: Bool
    @Environment(\.linePalette) private var palette

    var body: some View {
        ScrollView {
            LineFacts(
                name: line.name, frequency: engine.frequency(of: line.id, on: ServiceDate(now)),
                staleSince: engine.timetable.staleSince(on: ServiceDate(now)), neighbours: neighbours)
            LineSpine(
                stations: store.diagrams[line.id].stations, timetable: engine.timetable,
                color: palette.color(forLine: line.id),
                trains: trains, selection: $selection)
        }
        .contentShape(.rect)
        .gesture(TapGesture().onEnded { selection = nil }, isEnabled: tapCloses)
    }
}

/// The lines before and after a line, in the order of the chips.
private struct Neighbours {
    let previous: String?
    let next: String?

    init(of chosen: LineSummary, in lines: [LineSummary]) {
        let index = lines.firstIndex { $0.id == chosen.id }
        previous = index.flatMap { $0 > lines.startIndex ? lines[$0 - 1].name : nil }
        next = index.flatMap { $0 + 1 < lines.endIndex ? lines[$0 + 1].name : nil }
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
    /// The lines VoiceOver's swipe up and down on the name moves to, as a sideways swipe does.
    let neighbours: Neighbours
    @AppStorage(ChosenLine.key) private var chosenName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: name)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: neighbours.next.map { chosenName = $0 }
                    case .decrement: neighbours.previous.map { chosenName = $0 }
                    @unknown default: break
                    }
                }
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
