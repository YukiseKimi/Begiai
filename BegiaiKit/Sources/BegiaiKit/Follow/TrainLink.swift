import Foundation

/// A link to one train on one service day, `begiai://train?trip=<trip id>&day=<yyyymmdd>`:
/// a tap on the Live Activity opens that train's page with it. The trip id is the feed's,
/// which stays the same when a newer timetable numbers the trips again.
public struct TrainLink: Equatable, Sendable {
    public static let scheme = "begiai"
    static let host = "train"

    public let trip: String
    public let day: ServiceDate

    public init(trip: String, day: ServiceDate) {
        self.trip = trip
        self.day = day
    }

    /// Nil for a link that is not a train's, or whose trip or day does not read.
    public init?(url: URL) {
        guard url.scheme == Self.scheme, url.host() == Self.host,
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
            let trip = items.first(where: { $0.name == "trip" })?.value, !trip.isEmpty,
            let number = items.first(where: { $0.name == "day" })?.value.flatMap({ Int($0) }),
            let day = ServiceDate(number: number)
        else { return nil }
        self.init(trip: trip, day: day)
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.queryItems = [URLQueryItem(name: "trip", value: trip), URLQueryItem(name: "day", value: String(day.number))]
        return components.url!
    }
}

extension FollowedTrain {
    /// The link that opens this train's page.
    public var link: TrainLink? {
        ServiceDate(number: day).map { TrainLink(trip: trip, day: $0) }
    }
}

extension MotionEngine {
    /// The train a link names, at a moment: nil when the timetable has no such trip on that
    /// day, or the train has arrived, so the app opens the map and says so instead of a page with no train.
    public func train(for link: TrainLink, at date: Date) -> TrainState? {
        guard let trip = timetable.trips.firstIndex(where: { $0.id == link.trip }),
            timetable.services[timetable.trips[trip].service].runs(on: link.day)
        else { return nil }
        return train(TrainState.ID(trip: trip, day: link.day), at: date)
    }
}
