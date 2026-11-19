import BegiaiKit
import SwiftData
import SwiftUI

struct LineDiagramTab: View {
    let store: TimetableStore
    @Environment(\.timeSource) private var time
    /// The name of the last line the user looked at; a name stays the same in a new timetable.
    @AppStorage("lineDiagram.line") private var chosenName = ""
    @Query private var stars: [Star]
    @State private var selection: DiagramSelection?
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
            ProgressView()
        }
    }

    private func content(engine: MotionEngine, now: Date) -> some View {
        let trains = engine.trains(at: now)
        let starred = Set(stars.filter { $0.kind == StarKind.line.rawValue }.map(\.name))
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
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(line.id == chosen ? Color.white : Color.primary)
                    .background(line.id == chosen ? palette.color(forLine: line.id) : Color.secondary.opacity(0.15), in: .capsule)
                    .accessibilityAddTraits(line.id == chosen ? .isSelected : [])
                    .accessibilityIdentifier(A11yID.LineDiagram.chip)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollPosition(id: .constant(chosen), anchor: .center)
    }
}
