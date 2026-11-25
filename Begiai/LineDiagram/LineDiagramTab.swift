import BegiaiKit
import SwiftData
import SwiftUI

struct LineDiagramTab: View {
    let store: TimetableStore
    /// The train or station open in the sheet; RootView holds it, so it knows when a page is open.
    @Binding var selection: DiagramSelection?
    @Environment(\.timeSource) private var time
    /// The name of the last line the user looked at; a name stays the same in a new timetable.
    @AppStorage("lineDiagram.line") private var chosenName = ""
    @Query private var stars: [Star]
    @Environment(\.linePalette) private var palette
    /// Regular on a wide screen such as the open iPhone Duo, where a page opens in a column.
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if let engine = store.engine {
            Group {
                if #available(iOS 27.1, *), sizeClass == .regular {
                    // On a wide screen the train or station opens in a column over the diagram's
                    // trailing side, as the map's panel does.
                    MapColumn(identifier: A11yID.LineDiagram.column, shows: selection != nil) { insets in
                        diagram(engine: engine)
                            .safeAreaPadding(.trailing, insets.trailing)
                    } panel: {
                        if let selection {
                            DiagramSheet(engine: engine, selection: selection) { self.selection = nil }
                                // A new train or station starts its page afresh, as a new sheet does.
                                .id(selection)
                        }
                    }
                } else {
                    diagram(engine: engine)
                }
            }
            // The sheet holds the page only on a narrow screen: a fold or an unfold moves the page
            // between the sheet and the column, and the dismissed sheet does not close it.
            .sheet(item: inSheet) { chosen in
                DiagramSheet(engine: engine, selection: chosen) { selection = nil }
                    .presentationDetents([.medium, .large])
            }
        } else {
            TimetableUnavailable(state: store.state)
        }
    }

    private func diagram(engine: MotionEngine) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            content(engine: engine, now: time.now)
        }
    }

    /// True where the page opens in a column rather than a sheet.
    private var inColumn: Bool {
        guard #available(iOS 27.1, *) else { return false }
        return sizeClass == .regular
    }

    /// The selection, while a sheet shows it.
    private var inSheet: Binding<DiagramSelection?> {
        Binding {
            inColumn ? nil : selection
        } set: { chosen in
            if !inColumn { selection = chosen }
        }
    }

    private func content(engine: MotionEngine, now: Date) -> some View {
        let trains = engine.trains(at: now)
        let starred = stars.names(.line)
        let lines = engine.lineSummaries(at: now, trains: trains, starred: starred)
        let chosen = lines.first { $0.name == chosenName } ?? lines.first
        return VStack(spacing: 0) {
            LineChips(lines: lines, chosen: chosen?.id) { chosenName = $0.name }
            if let chosen {
                let diagram = store.diagrams[chosen.id]
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: chosen.name)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier(A11yID.LineDiagram.page)
                        FrequencyText(frequency: engine.frequency(of: chosen.id, on: ServiceDate(now)))
                        Text(.trainEstimated)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        StaleNote(since: engine.timetable.staleSince(on: ServiceDate(now)))
                        NoticesLink()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    LineSpine(
                        diagram: diagram, timetable: engine.timetable, color: palette.color(forLine: chosen.id),
                        trains: trains.compactMap { train in diagram.place(of: train).map { (train, $0) } }
                    ) { selection = $0 }
                }
            } else {
                ContentUnavailableView(.diagramNoLines, systemImage: "tram")
            }
        }
    }
}

private struct LineChips: View {
    let lines: [LineSummary]
    let chosen: Int?
    let choose: (LineSummary) -> Void
    @Environment(\.linePalette) private var palette

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(lines) { line in
                    Button {
                        choose(line)
                    } label: {
                        Text(verbatim: line.name)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(
                                line.id == chosen
                                    ? AnyShapeStyle(ReadableText(background: palette.color(forLine: line.id)))
                                    : AnyShapeStyle(Color.primary)
                            )
                            .background(
                                line.id == chosen ? palette.color(forLine: line.id) : Color.secondary.opacity(0.15), in: .capsule
                            )
                            // The chip looks small; its tap area is the full 44 points high.
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(line.id == chosen ? .isSelected : [])
                    .accessibilityIdentifier(A11yID.LineDiagram.chip)
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
