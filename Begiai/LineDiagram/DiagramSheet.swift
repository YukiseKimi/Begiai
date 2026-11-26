import BegiaiKit
import SwiftData
import SwiftUI

enum DiagramSelection: Hashable, Identifiable {
    case train(TrainState.ID)
    case station(Int)

    var id: Self { self }
}

/// The train page or the station board, in a sheet over the Line Diagram.
struct DiagramSheet: View {
    let engine: MotionEngine
    let selection: DiagramSelection
    let close: () -> Void
    @Environment(\.timeSource) private var time
    @Query private var stars: [Star]
    @Environment(\.linePalette) private var palette
    /// A station opened from the train's page: shown in place, so the sheet stays up.
    @State private var opened: DiagramSelection?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = time.now
            VStack(alignment: .leading, spacing: 12) {
                switch opened ?? selection {
                case .train(let id):
                    let train = engine.train(id, at: now)
                    let timeline = train.map(engine.timeline(of:))
                    let color = palette.color(forLine: engine.timetable.trips[id.trip].line)
                    TrainPage(
                        timeline: timeline, color: color, now: now, exit: .close,
                        openStation: { opened = .station($0) }, close: close)
                    if let timeline {
                        StopList(timeline: timeline, color: color)
                    }
                case .station(let station):
                    let name = engine.timetable.stations[station].name
                    let panel = StationPanel(
                        index: station, name: name, starred: starred.contains(name), engine: engine, now: now, exit: .close,
                        close: close)
                    panel.header
                    panel.board
                }
            }
            .padding(.top)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var starred: Set<String> {
        stars.names(.station)
    }
}
