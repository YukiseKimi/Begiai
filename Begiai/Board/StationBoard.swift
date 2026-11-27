import BegiaiKit
import SwiftUI

/// An open station's board: its next departures, for the map's panel and the Line Diagram's
/// sheet, each with `StationHeader` above it. The map's panel lays out a header, which drags to
/// resize it, apart from a content area, which scrolls; so the header and the board are two views.
struct StationBoard: View {
    let engine: MotionEngine
    let station: Int
    let now: Date
    /// The next departures, the same array while they stay the same, so the board compares
    /// them cheaply each second.
    @State private var departures: [Departure] = []

    var body: some View {
        LEDBoard(departures: departures, now: now)
            .onChange(of: BoardMoment(station: station, now: now), initial: true) {
                let latest = engine.departures(from: station, at: now)
                if latest != departures { departures = latest }
            }
    }
}

private struct BoardMoment: Equatable {
    let station: Int
    let now: Date
}
