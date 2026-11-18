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

/// How often the trains of a line leave its first end, at rush hour and at midday.
public struct LineFrequency: Equatable, Sendable {
    public enum Period: Equatable, Sendable {
        case noTrain
        case one
        /// More than one train, but never two in one block of hours, so there is no gap.
        case trains(Int)
        /// The shortest and the longest gap between two departures, in minutes, to the nearest 5
        /// and never under 5.
        case every(ClosedRange<Int>)
    }

    /// 06:00–09:00 and 16:00–19:00.
    public let rush: Period
    /// 10:00–15:00.
    public let midday: Period

    public init(rush: Period, midday: Period) {
        self.rush = rush
        self.midday = midday
    }
}

extension MotionEngine {
    static let rushHours = [6..<9, 16..<19]
    static let middayHours = [10..<15]

    public func frequency(of line: Int, on date: ServiceDate) -> LineFrequency {
        guard let end = timetable.lines[line].ends.first else { return LineFrequency(rush: .noTrain, midday: .noTrain) }
        let departures = day(date).trips.compactMap { trip -> Double? in
            let stops = timetable.trips[trip].stops
            guard timetable.trips[trip].line == line,
                let at = stops.indices.dropLast().first(where: { stops[$0].station == end })
            else { return nil }
            return schedule(of: trip).departures[at]
        }
        .sorted()
        func period(_ hours: [Range<Int>]) -> LineFrequency.Period {
            let groups = hours.map { range in departures.filter { range.contains(Int($0) / 3600) } }
            let gaps = groups.flatMap { group in zip(group, group.dropFirst()).map { max(5, Int((($1 - $0) / 300).rounded()) * 5) } }
            guard let shortest = gaps.min(), let longest = gaps.max() else {
                let count = groups.joined().count
                return count == 0 ? .noTrain : count == 1 ? .one : .trains(count)
            }
            return .every(shortest...longest)
        }
        return LineFrequency(rush: period(Self.rushHours), midday: period(Self.middayHours))
    }
}
