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

    var body: some View {
        if let engine = store.engine {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                content(engine: engine, now: time.now)
            }
            .sheet(item: $selection) { chosen in
                DiagramSheet(engine: engine, selection: chosen) { selection = nil }
                    .presentationDetents([.medium, .large])
            }
        } else {
            TimetableUnavailable(state: store.state)
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
