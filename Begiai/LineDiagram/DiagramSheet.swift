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
    @Environment(\.modelContext) private var modelContext
    @Query private var stars: [Star]
    @Environment(\.linePalette) private var palette

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = time.now
            VStack(alignment: .leading, spacing: 12) {
                switch selection {
                case .train(let id):
                    let train = engine.train(id, at: now)
                    let timeline = train.map(engine.timeline(of:))
                    let color = palette.color(forLine: engine.timetable.trips[id.trip].line)
                    TrainPage(timeline: timeline, color: color, now: now, exit: .close, close: close)
                    if let timeline {
                        StopList(timeline: timeline, color: color)
                    }
                case .station(let station):
                    let name = engine.timetable.stations[station].name
                    StationHeader(name: name, starred: starred.contains(name), exit: .close, close: close) {
                        modelContext.toggleStarOrRollBack(.station, name: name, at: now)
                    }
                    LEDBoard(departures: engine.departures(from: station, at: now), now: now)
                }
            }
            .padding(.top)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var starred: Set<String> {
        Set(stars.filter { $0.kind == StarKind.station.rawValue }.map(\.name))
    }
}
