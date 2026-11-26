import Foundation

public struct TrainState: Equatable, Sendable, Identifiable {
    public struct ID: Hashable, Sendable {
        public let trip: Int
        public let day: ServiceDate
    }

    public enum Phase: Equatable, Sendable {
        case boarding
        case atStation
        case running
        case arrived
    }

    public let trip: Int
    public let day: ServiceDate
    public let phase: Phase
    public let metres: Double
    public let coordinate: Coordinate
    public let heading: Double
    public let speed: Double
    public let lastStop: Int
    public let nextStop: Int

    public var id: ID { ID(trip: trip, day: day) }
}

public struct MotionEngine: Sendable {
    public static let minimumDwell = 30.0
    public static let borrowLimit = 120.0 / 3.6
    public static let minimumRun = 30.0

    public let timetable: Timetable
    /// The name of each station, by station index.
    public let stationNames: [String]
    /// How many trips call at each station, by station index: the search puts busier stations
    /// first. Counted once here, not at each keystroke.
    public let callsPerStation: [Int]
    private let schedules: [(arrivals: [Double], departures: [Double])]
    private let days = DayCache()

    public init(timetable: Timetable) {
        self.timetable = timetable
        stationNames = timetable.stations.map(\.name)
        callsPerStation = timetable.callsPerStation
        schedules = timetable.trips.map(Self.times)
    }

    public func schedule(of trip: Int) -> (arrivals: [Double], departures: [Double]) {
        schedules[trip]
    }

    public func trains(at date: Date) -> [TrainState] {
        timetable.runningTrips(at: date, until: { schedules[$0].arrivals.last ?? 0 }, days: day).compactMap(state)
    }

    func day(_ date: ServiceDate) -> ServiceDay {
        days.day(date, in: timetable)
    }

    /// The train with this ID at a moment, so that a chosen train stays chosen as it moves.
    /// Nil once it arrives.
    public func train(_ id: TrainState.ID, at date: Date) -> TrainState? {
        let train = state(of: RunningTrip(trip: id.trip, day: id.day, seconds: date.timeIntervalSince(id.day.timetableZero)))
        return train?.phase == .arrived ? nil : train
    }

    func state(of running: RunningTrip) -> TrainState? {
        let trip = timetable.trips[running.trip]
        let stops = trip.stops
        guard stops.count >= 2 else { return nil }
        let (arrivals, departures) = schedules[running.trip]
        let now = running.seconds
        let last = stops.count - 1
        let phase: TrainState.Phase
        var metres: Double
        var speed = 0.0
        var lastStop: Int
        var nextStop: Int
        if now < departures[0] {
            (phase, metres, lastStop, nextStop) = (.boarding, stops[0].metres, 0, min(1, last))
        } else if now >= arrivals[last] {
            (phase, metres, lastStop, nextStop) = (.arrived, stops[last].metres, last, last)
        } else {
            var k = 0
            while k < last, now >= arrivals[k + 1] { k += 1 }
            if now < departures[k] {
                (phase, metres, lastStop, nextStop) = (.atStation, stops[k].metres, k, min(k + 1, last))
            } else {
                let motion = SpeedProfile.distance(
                    length: stops[k + 1].metres - stops[k].metres,
                    duration: arrivals[k + 1] - departures[k],
                    elapsed: now - departures[k])
                (phase, metres, speed, lastStop, nextStop) = (.running, stops[k].metres + motion.metres, motion.speed, k, k + 1)
            }
        }
        guard let point = timetable.shapes[trip.shape].point(atMetres: metres) else { return nil }
        return TrainState(
            trip: running.trip, day: running.day, phase: phase, metres: metres, coordinate: point.coordinate,
            heading: point.heading, speed: speed, lastStop: lastStop, nextStop: nextStop)
    }

    static func times(of trip: Trip) -> (arrivals: [Double], departures: [Double]) {
        let stops = trip.stops
        var arrivals = stops.map { Double($0.arrival) }
        var departures = stops.map { Double($0.departure) }
        for k in stops.indices.dropFirst() {
            if k < stops.count - 1, arrivals[k] >= departures[k] {
                let run = arrivals[k] - Self.minimumDwell - departures[k - 1]
                let length = stops[k].metres - stops[k - 1].metres
                if run > 0, length / run < Self.borrowLimit { arrivals[k] = departures[k] - Self.minimumDwell }
            }
            arrivals[k] = max(arrivals[k], departures[k - 1] + Self.minimumRun)
            departures[k] = max(departures[k], arrivals[k])
        }
        return (arrivals, departures)
    }
}
