import Foundation

public struct TrainTimeline: Equatable, Sendable {
    public struct Stop: Equatable, Sendable, Identifiable {
        public let id: Int
        public let station: String
        /// The station's index in the timetable, to open its board.
        public let stationIndex: Int
        public let arrival: Date
        public let departure: Date
        public let passed: Bool
    }

    public let origin: String
    public let destination: String
    public let firstDeparture: Date
    public let stops: [Stop]
    public let nextStop: Int?
    public let standingAt: Int?
    public let progressToNext: Double
}

extension MotionEngine {
    /// The stop of its trip a train stands at: its first while it boards, its last while it
    /// stands at a station, else nil.
    public func standingStop(of train: TrainState) -> Int? {
        switch train.phase {
        case .boarding: 0
        case .atStation: train.lastStop
        case .running, .arrived: nil
        }
    }

    /// The station a train stands at, as an index in the timetable's stations.
    public func standingStation(of train: TrainState) -> Int? {
        standingStop(of: train).map { timetable.trips[train.trip].stops[$0].station }
    }

    public func timeline(of train: TrainState) -> TrainTimeline {
        let trip = timetable.trips[train.trip]
        let zero = train.day.timetableZero
        let schedule = schedule(of: train.trip)
        let standing = standingStop(of: train)
        let next: Int? =
            switch train.phase {
            case .boarding, .running: train.nextStop
            case .atStation: train.lastStop + 1 < trip.stops.count ? train.lastStop + 1 : nil
            case .arrived: nil
            }
        let firstUnpassed = standing ?? next ?? trip.stops.count
        let stops = trip.stops.enumerated().map { index, stop in
            TrainTimeline.Stop(
                id: index,
                station: timetable.stations[stop.station].name,
                stationIndex: stop.station,
                arrival: zero.addingTimeInterval(schedule.arrivals[index]),
                departure: zero.addingTimeInterval(schedule.departures[index]),
                passed: index < firstUnpassed)
        }
        let from = trip.stops[train.lastStop].metres
        let to = trip.stops[train.nextStop].metres
        let progress = train.phase == .running && to > from ? min(1, max(0, (train.metres - from) / (to - from))) : 0
        return TrainTimeline(
            origin: stops.first?.station ?? "",
            destination: stops.last?.station ?? "",
            firstDeparture: stops.first?.departure ?? zero,
            stops: stops,
            nextStop: next,
            standingAt: standing,
            progressToNext: progress)
    }
}
