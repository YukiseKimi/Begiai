import Foundation

/// A train that the rider follows, as its Live Activity shows it: the line, the stops and
/// their timetable times. It is fixed when Follow starts it. Where the train is at a moment
/// comes from these times alone, so the Lock Screen can show it with no server.
public struct FollowedTrain: Codable, Hashable, Sendable {
    public struct Stop: Codable, Hashable, Sendable {
        public let name: String
        public let arrival: Date
        public let departure: Date

        public init(name: String, arrival: Date, departure: Date) {
            self.name = name
            self.arrival = arrival
            self.departure = departure
        }
    }

    /// The trip's id in the timetable feed, which stays the same when a new timetable
    /// numbers the trips again.
    public let trip: String
    /// The service day, as `ServiceDate.number`.
    public let day: Int
    public let line: String
    /// The line's slot in the palette.
    public let colour: Int
    public let stops: [Stop]
    /// How far the device clock is ahead of the train's clock. Zero, except in a sealed
    /// launch, whose clock is pinned: the activity then starts at the pinned time and runs on
    /// in real time, so its timers count as they would.
    public let shift: TimeInterval

    public init(trip: String, day: Int, line: String, colour: Int, stops: [Stop], shift: TimeInterval = 0) {
        precondition(stops.count >= 2, "a followed train has at least two stops")
        self.trip = trip
        self.day = day
        self.line = line
        self.colour = colour
        self.stops = stops
        self.shift = shift
    }

    public var origin: String { stops[0].name }
    public var destination: String { stops[stops.count - 1].name }
    public var departure: Date { stops[0].departure }
    public var arrival: Date { stops[stops.count - 1].arrival }

    /// True for the same trip on the same day, whatever its times or clock.
    public func isSameTrain(as other: FollowedTrain) -> Bool {
        trip == other.trip && day == other.day
    }

    public func isTrain(trip: String, day: ServiceDate) -> Bool {
        self.trip == trip && self.day == day.number
    }
}

extension FollowedTrain {
    /// Where the train is, by the timetable.
    public enum Place: Codable, Hashable, Sendable {
        /// Before it leaves its first stop.
        case boarding
        /// Standing at a stop between its first and its last.
        case at(Int)
        /// On the way from this stop to the next.
        case leaving(Int)
        /// At or after its last arrival.
        case arrived
    }

    public func place(at date: Date) -> Place {
        let last = stops.count - 1
        if date < stops[0].departure { return .boarding }
        if date >= stops[last].arrival { return .arrived }
        var k = 0
        while k < last - 1, date >= stops[k + 1].arrival { k += 1 }
        return date < stops[k].departure ? .at(k) : .leaving(k)
    }

    /// The stops the train has left: a stop it stands at is not passed yet.
    public func passed(_ place: Place) -> Int {
        switch place {
        case .boarding: 0
        case .at(let stop): stop
        case .leaving(let stop): stop + 1
        case .arrived: stops.count
        }
    }

    /// The stop the train is due at next, with the time it is due: its departure from the
    /// stop it stands at, else its arrival at the next. Nil once it has arrived.
    public func next(_ place: Place) -> (stop: Int, time: Date, standing: Bool)? {
        switch place {
        case .boarding: (0, stops[0].departure, true)
        case .at(let stop): (stop, stops[stop].departure, true)
        case .leaving(let stop): (stop + 1, stops[stop + 1].arrival, false)
        case .arrived: nil
        }
    }

    /// Each run between two stops, from its departure to the next arrival, in the train's time.
    public var runs: [ClosedRange<Date>] {
        stops.indices.dropLast().map { k in
            stops[k].departure...max(stops[k].departure, stops[k + 1].arrival)
        }
    }

    /// Where each stop sits on the journey bar, from 0 to 1. Each run between two stops takes
    /// a part of the bar by the time it lasts, but at least `minimumShare` of it, so that
    /// stops a short run apart keep their dots apart.
    public func stopFractions(minimumShare: Double = 0) -> [Double] {
        let durations = runs.map { $0.upperBound.timeIntervalSince($0.lowerBound) }
        let total = durations.reduce(0, +)
        let share = min(max(minimumShare, 0), 1 / Double(durations.count))
        var sum = 0.0
        let fractions = durations.map { duration in
            sum += share + (1 - share * Double(durations.count)) * (total > 0 ? duration / total : 1 / Double(durations.count))
            return min(sum, 1)
        }
        return [0] + fractions.dropLast() + [1]
    }
}

extension FollowedTrain {
    /// The device time of a time on the train's clock, for the timers of the Live Activity.
    public func deviceDate(_ date: Date) -> Date { date.addingTimeInterval(shift) }

    /// The train's time at a device time.
    public func trainDate(_ device: Date) -> Date { device.addingTimeInterval(-shift) }

    /// What the Live Activity shows until the next update, at a device time.
    public func status(at device: Date) -> Status {
        Status(place: place(at: trainDate(device)))
    }

    /// The device time after which the "Next" line no longer holds without an update: the
    /// last arrival. The activity then shows the train as arrived.
    public var staleDate: Date { deviceDate(arrival) }

    /// The end of the minutes countdown to the last arrival, on the device clock. A minutes
    /// format drops the seconds left, so the end is 59 seconds late: the countdown then reads
    /// what the clock says, “35m” from 08:47 to a 09:22 arrival, and “0m” only at the arrival.
    public var countdownEnd: Date { deviceDate(arrival).addingTimeInterval(59) }

    /// How long the widest reading of the countdown from `device` on is: its hours and 59
    /// minutes, or under an hour the reading at `device`, as the minutes only fall from there.
    /// A live text takes all the width it is offered, so a still text of this reading sets its
    /// width.
    public func countdownWidest(at device: Date) -> TimeInterval {
        let left = max(0, countdownEnd.timeIntervalSince(device))
        guard left >= 3600 else { return left }
        return (left / 3600).rounded(.down) * 3600 + 59 * 60
    }

    /// How long an ended activity stays on the Lock Screen after the train arrives.
    public static let linger: TimeInterval = 15 * 60

    /// When the system removes the activity once the app ends it: a short while after the
    /// last arrival, so the rider sees that the train is in. Nil for at once: before the train
    /// arrives, as the rider stopped following it, or once that while has passed.
    public func dismissal(at device: Date) -> Date? {
        guard hasArrived(at: device) else { return nil }
        let end = deviceDate(arrival).addingTimeInterval(Self.linger)
        return end > device ? end : nil
    }

    /// True once the train is past its last arrival, at a device time.
    public func hasArrived(at device: Date) -> Bool {
        trainDate(device) >= arrival
    }

    /// The device time of the next change of `status`, so the app, while it runs, can update
    /// the activity then. Nil once the train has arrived.
    public func nextChange(after device: Date) -> Date? {
        let date = trainDate(device)
        let events = stops.flatMap { [$0.arrival, $0.departure] }
        return events.filter { $0 > date }.min().map(deviceDate)
    }

    /// The dynamic part of the Live Activity: where the train was at the last update.
    public struct Status: Codable, Hashable, Sendable {
        public let place: Place

        public init(place: Place) {
            self.place = place
        }
    }
}

extension FollowedTrain {
    /// The train of a timeline, to follow. `shift` is the device time minus the app's time.
    public init(timeline: TrainTimeline, trip: String, day: ServiceDate, line: String, colour: Int, shift: TimeInterval = 0) {
        self.init(
            trip: trip, day: day.number, line: line, colour: colour,
            stops: timeline.stops.map { Stop(name: $0.station, arrival: $0.arrival, departure: $0.departure) }, shift: shift)
    }
}

/// What to do with the Live Activities that are running when the app starts or comes back.
public struct FollowReview: Equatable, Sendable {
    /// The train still followed: the newest activity whose train has not arrived.
    public let followed: FollowedTrain?
    /// The indices of the activities to end: arrived trains, and older ones that a newer
    /// activity replaced.
    public let ended: [Int]

    /// `activities` are oldest first, as the system lists them.
    public init(activities: [FollowedTrain], at device: Date) {
        let running = activities.indices.filter { !activities[$0].hasArrived(at: device) }
        let kept = running.last
        followed = kept.map { activities[$0] }
        ended = activities.indices.filter { $0 != kept }
    }
}
