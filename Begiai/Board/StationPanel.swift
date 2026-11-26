import BegiaiKit
import SwiftUI

/// An open station: its name, star and board, worked out in one place for the map's panel and
/// the Line Diagram's sheet. The map's panel lays out a header, which drags to resize it, apart
/// from a content area, which scrolls; so this view gives its header and its board as two pieces.
struct StationPanel {
    let index: Int
    let name: String
    let starred: Bool
    let engine: MotionEngine
    let now: Date
    var exit = PageExit.back
    let close: () -> Void

    var header: some View {
        StationHeader(name: name, starred: starred, exit: exit, close: close)
    }

    var board: some View {
        LEDBoard(departures: engine.departures(from: index, at: now), now: now)
    }
}
