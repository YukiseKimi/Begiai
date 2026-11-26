import BegiaiKit
import SwiftData
import SwiftUI

struct LineDiagramTab: View {
    let store: TimetableStore
    /// The train or station open in the sheet; RootView holds it, so it knows when a page is open.
    @Binding var selection: PageSelection?
    /// Regular on a wide screen such as the open iPhone Duo, where a page opens in a column.
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// The diagram's own safe area on its trailing side, such as the Duo's tab strip.
    @State private var diagramSafeTrailing: CGFloat = 0

    var body: some View {
        if let engine = store.engine {
            Group {
                if #available(iOS 27.1, *), sizeClass == .regular {
                    // On a wide screen the train or station opens in a column over the diagram's
                    // trailing side, as the map's panel does.
                    MapColumn(identifier: A11yID.LineDiagram.column, shows: selection != nil) { insets in
                        // The inset is from the screen's edge. The diagram stops at its safe area,
                        // short of the tab strip on the right of the open Duo held wide, so it
                        // pads only the rest.
                        LineDiagramPage(
                            engine: engine, diagrams: store.diagrams, selection: $selection, tapCloses: selection != nil
                        )
                        .safeAreaPadding(.trailing, max(0, insets.trailing - diagramSafeTrailing))
                        .onGeometryChange(for: CGFloat.self) {
                            $0.safeAreaInsets.trailing
                        } action: {
                            diagramSafeTrailing = $0
                        }
                    } panel: {
                        if let selection {
                            DiagramSheet(engine: engine, page: selection, selection: $selection)
                                // A new train or station starts its page afresh, as a new sheet does.
                                .id(selection)
                        }
                    }
                } else {
                    LineDiagramPage(engine: engine, diagrams: store.diagrams, selection: $selection, tapCloses: false)
                }
            }
            // The sheet holds the page only on a narrow screen: a fold or an unfold moves the page
            // between the sheet and the column, and the dismissed sheet does not close it.
            .sheet(item: $selection[shownIf: !inColumn]) { chosen in
                DiagramSheet(engine: engine, page: chosen, selection: $selection)
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

extension Optional {
    /// This value while `shown`, else nil; a write while it shows passes through. A sheet bound
    /// this way presents the value only where it should show it.
    subscript(shownIf shown: Bool) -> Wrapped? {
        get { shown ? self : nil }
        set { if shown { self = newValue } }
    }
}

/// Where the Line Diagram keeps the name of the last line the rider looked at; a name stays the
/// same in a new timetable.
private enum ChosenLine {
    static let key = "lineDiagram.line"
}

/// The Line Diagram, once a second: the chips of the lines, and the chosen line's facts and spine.
private struct LineDiagramPage: View {
    let engine: MotionEngine
    /// The diagram of each line, by line index.
    let diagrams: [LineDiagram]
    @Binding var selection: PageSelection?
    /// True where a tap away from the trains and stations closes the open page: in the column,
    /// as a tap on the map closes the map's page. A sheet closes on such a tap by itself.
    let tapCloses: Bool
    @Environment(\.timeSource) private var time
    @AppStorage(ChosenLine.key) private var chosenName = ""
    @Query private var stars: [Star]
    @Environment(\.linePalette) private var palette

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = time.now
            let trains = engine.trains(at: now)
            let lines = engine.lineSummaries(at: now, trains: trains, starred: stars.names(.line))
            let chosen = lines.first { $0.name == chosenName } ?? lines.first
            VStack(spacing: 0) {
                LineChips(lines: lines, chosen: chosen?.id)
                    // A scroll view draws its content into the safe area along its axis; the chips
                    // stay in the row's own frame, clear of the status bar and the tab strip that the
                    // open Duo shows on the right.
                    .clipped()
                if let chosen {
                    let diagram = diagrams[chosen.id]
                    ScrollView {
                        LineFacts(line: chosen, engine: engine, now: now)
                        LineSpine(
                            diagram: diagram, timetable: engine.timetable, color: palette.color(forLine: chosen.id),
                            trains: trains.compactMap { train in diagram.place(of: train).map { (train, $0) } },
                            selection: $selection)
                    }
                    .contentShape(.rect)
                    .gesture(TapGesture().onEnded { selection = nil }, isEnabled: tapCloses)
                } else {
                    ContentUnavailableView(.diagramNoLines, systemImage: "tram")
                }
            }
        }
    }
}

/// The chosen line's name, how often its trains leave, and the notes on what the diagram shows.
private struct LineFacts: View {
    let line: LineSummary
    let engine: MotionEngine
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: line.name)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(A11yID.LineDiagram.page)
            FrequencyText(frequency: engine.frequency(of: line.id, on: ServiceDate(now)))
            Text(.trainEstimated)
                .font(.footnote)
                .foregroundStyle(.secondary)
            StaleNote(since: engine.timetable.staleSince(on: ServiceDate(now)))
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
                    LineChip(line: line, isChosen: line.id == chosen)
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
    let line: LineSummary
    let isChosen: Bool
    @AppStorage(ChosenLine.key) private var chosenName = ""
    @Environment(\.linePalette) private var palette

    var body: some View {
        Button {
            chosenName = line.name
        } label: {
            Text(verbatim: line.name)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(
                    isChosen
                        ? AnyShapeStyle(ReadableText(background: palette.color(forLine: line.id)))
                        : AnyShapeStyle(Color.primary)
                )
                .background(isChosen ? palette.color(forLine: line.id) : Color.secondary.opacity(0.15), in: .capsule)
                // The chip looks small; its tap area is the full 44 points high.
                .frame(minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityIdentifier(A11yID.LineDiagram.chip)
    }
}
