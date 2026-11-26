import BegiaiKit
import SwiftData
import SwiftUI

/// The train page or the station board, in a sheet over the Line Diagram, or in its column on
/// a wide screen.
struct DiagramSheet: View {
    let engine: MotionEngine
    /// The train or station the sheet opened on.
    let page: PageSelection
    /// The Line Diagram's open page: Close clears it.
    @Binding var selection: PageSelection?
    @Environment(\.timeSource) private var time
    @Query private var stars: [Star]
    @Environment(\.linePalette) private var palette
    /// A station opened from the train's page: shown in place, so the sheet stays up.
    @State private var opened: PageSelection?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = time.now
            VStack(alignment: .leading, spacing: 12) {
                switch opened ?? page {
                case .train(let id):
                    let train = engine.train(id, at: now)
                    let timeline = train.map(engine.timeline(of:))
                    let color = palette.color(forLine: engine.timetable.trips[id.trip].line)
                    TrainPage(
                        timeline: timeline, color: color, now: now, exit: .close, selection: $selection, stationPage: $opened)
                    if let timeline {
                        StopList(train: id, timeline: timeline, color: color)
                    }
                case .station(let station):
                    let name = engine.stationNames[station]
                    StationHeader(name: name, starred: stars.names(.station).contains(name), exit: .close, selection: $selection)
                    StationBoard(engine: engine, station: station, now: now)
                }
            }
            .padding(.top)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
