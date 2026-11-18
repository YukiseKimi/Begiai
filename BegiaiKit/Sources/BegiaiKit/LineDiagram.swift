import Foundation

/// One line as a column of stations, from its first end to its last, and the place of each
/// of its trains on that column.
public struct LineDiagram: Sendable {
    public struct Place: Equatable, Sendable {
        public enum Direction: Sendable {
            /// Toward the last station of the diagram.
            case down
            /// Toward the first station of the diagram.
            case up
        }

        /// The row of the station the train left or stands at.
        public let from: Int
        /// The row of the next station the train stops at; `from` while it stands.
        public let to: Int
        /// How far the train is from `from` to `to`, by distance on the track.
        public let fraction: Double
        public let direction: Direction

        /// The position on the column, in rows: 1.5 is halfway between rows 1 and 2.
        public var row: Double { Double(from) + Double(to - from) * fraction }
    }

    public let line: Int
    /// The stations of the line, in order from its first end.
    public let stations: [Int]
    private let rows: [Int: Int]
    private let timetable: Timetable

    public init(line: Int, timetable: Timetable) {
        self.line = line
        self.timetable = timetable
        stations = Self.order(of: line, in: timetable)
        rows = Dictionary(uniqueKeysWithValues: stations.enumerated().map { ($1, $0) })
    }

    public func place(of train: TrainState) -> Place? {
        let trip = timetable.trips[train.trip]
        guard trip.line == line, let first = rows[trip.stops[0].station],
            let last = rows[trip.stops[trip.stops.count - 1].station],
            let from = rows[trip.stops[train.lastStop].station], let to = rows[trip.stops[train.nextStop].station]
        else { return nil }
        let start = trip.stops[train.lastStop].metres
        let length = trip.stops[train.nextStop].metres - start
        let fraction = train.phase == .running && length > 0 ? min(max((train.metres - start) / length, 0), 1) : 0
        return Place(from: from, to: to, fraction: fraction, direction: last >= first ? .down : .up)
    }

    /// Merges the stops of each trip of the line into one order. Each trip first points away
    /// from the line's first end; where two stations have no order, the one nearer that end
    /// goes first.
    static func order(of line: Int, in timetable: Timetable) -> [Int] {
        guard let end = timetable.lines[line].ends.first else { return [] }
        let home = timetable.stations[end].coordinate
        let distance = { (station: Int) in timetable.stations[station].coordinate.metres(to: home) }
        var after: [Int: Set<Int>] = [:]
        var before: [Int: Int] = [:]
        for trip in timetable.trips where trip.line == line {
            var stops = trip.stops.map(\.station)
            if distance(stops[0]) > distance(stops[stops.count - 1]) { stops.reverse() }
            for station in stops where after[station] == nil { after[station] = [] }
            for (a, b) in zip(stops, stops.dropFirst()) where after[a]?.insert(b).inserted == true {
                before[b, default: 0] += 1
            }
        }
        var ready = after.keys.filter { before[$0, default: 0] == 0 }
        var order: [Int] = []
        while !ready.isEmpty {
            ready.sort { distance($0) > distance($1) }
            let station = ready.removeLast()
            order.append(station)
            for next in after[station] ?? [] {
                before[next, default: 0] -= 1
                if before[next] == 0 { ready.append(next) }
            }
        }
        let left = after.keys.filter { !order.contains($0) }.sorted { distance($0) < distance($1) }
        return order + left
    }
}
