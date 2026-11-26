import BegiaiKit
import SwiftUI

/// An open station's board: its next departures, for the map's panel and the Line Diagram's
/// sheet, each with `StationHeader` above it. The map's panel lays out a header, which drags to
/// resize it, apart from a content area, which scrolls; so the header and the board are two views.
struct StationBoard: View {
    let engine: MotionEngine
    let station: Int
    let now: Date

    var body: some View {
        LEDBoard(departures: engine.departures(from: station, at: now), now: now)
    }
}
