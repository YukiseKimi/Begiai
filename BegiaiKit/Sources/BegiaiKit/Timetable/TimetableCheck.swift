import CryptoKit
import Foundation

/// Why a timetable cannot be used. The bundle tool refuses to write it, and the app refuses
/// to load it.
public enum TimetableProblem: Error, Equatable, CustomStringConvertible {
    case empty(String)
    case outOfRange(String)
    case noServiceOnFeedDate(Int)

    public var description: String {
        switch self {
        case .empty(let what): "no \(what)"
        case .outOfRange(let what): "out of range: \(what)"
        case .noServiceOnFeedDate(let date): "no trip runs on the feed date \(date)"
        }
    }
}

extension Timetable {
    /// The shape of timetable.json. An app reads only a bundle of the format that it knows.
    public static let format = 1

    /// After this many days the app says the date of its timetable: two nightly builds failed.
    public static let staleAfterDays = 3

    /// The day the timetable was built, in Vilnius; nil only for a timetable that fails `check()`.
    public var builtOn: ServiceDate? { ServiceDate(number: feedDate) }

    /// The day the timetable was built, when it is `staleAfterDays` or more days before `day`.
    public func staleSince(on day: ServiceDate) -> ServiceDate? {
        guard let built = builtOn, built.adding(days: Self.staleAfterDays) <= day else { return nil }
        return built
    }

    public func isStale(at date: Date) -> Bool { staleSince(on: ServiceDate(date)) != nil }

    /// Throws the first problem that would make the app show wrong or no trains: an empty
    /// list, an index that points at nothing, or no trip on the feed date.
    public func check() throws(TimetableProblem) {
        if stations.isEmpty { throw .empty("stations") }
        if lines.isEmpty { throw .empty("lines") }
        if trips.isEmpty { throw .empty("trips") }
        for (index, line) in lines.enumerated() where line.ends.isEmpty || !line.ends.allSatisfy(stations.indices.contains) {
            throw .outOfRange("the ends of line \(index)")
        }
        for trip in trips {
            guard lines.indices.contains(trip.line), shapes.indices.contains(trip.shape), services.indices.contains(trip.service)
            else { throw .outOfRange("trip \(trip.id)") }
            guard trip.stops.count >= 2, trip.stops.allSatisfy({ stations.indices.contains($0.station) })
            else { throw .outOfRange("the stops of trip \(trip.id)") }
        }
        guard let day = builtOn, trips.contains(where: { services[$0.service].runs(on: day) })
        else { throw .noServiceOnFeedDate(feedDate) }
    }
}

extension ServiceDate {
    /// A date written as YYYYMMDD, as in GTFS.
    public init?(number: Int) {
        let year = number / 10_000
        let month = number / 100 % 100
        let day = number % 100
        guard let date = Vilnius.calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        self.init(date)
        guard self.number == number else { return nil }
    }
}

/// manifest.json, beside timetable.json: the app reads it first, and downloads the bundle
/// only when it is newer.
public struct Manifest: Codable, Sendable, Equatable {
    public var format: Int
    public var feedDate: Int
    public var bytes: Int
    public var sha256: String

    public init(format: Int, feedDate: Int, bytes: Int, sha256: String) {
        self.format = format
        self.feedDate = feedDate
        self.bytes = bytes
        self.sha256 = sha256
    }

    /// The manifest of a bundle, as it is written to disk.
    public init(bundle data: Data, feedDate: Int) {
        self.init(format: Timetable.format, feedDate: feedDate, bytes: data.count, sha256: Self.hash(data))
    }

    /// True when `data` is the bundle that this manifest names.
    public func names(_ data: Data) -> Bool {
        data.count == bytes && Self.hash(data) == sha256
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
