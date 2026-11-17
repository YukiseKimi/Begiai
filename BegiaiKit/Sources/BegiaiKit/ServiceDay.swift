import Foundation

public struct ServiceDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date) {
        let parts = Vilnius.calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public var number: Int { year * 10_000 + month * 100 + day }

    public var midnight: Date {
        Vilnius.calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public var timetableZero: Date {
        Vilnius.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
            .addingTimeInterval(-12 * 3600)
    }

    public var weekdayIndex: Int {
        (Vilnius.calendar.component(.weekday, from: midnight) + 5) % 7
    }

    public func adding(days: Int) -> ServiceDate {
        ServiceDate(Vilnius.calendar.date(byAdding: .day, value: days, to: midnight)!)
    }

    public static func < (a: ServiceDate, b: ServiceDate) -> Bool { a.number < b.number }

    public var description: String { String(number) }
}

public struct RunningTrip: Equatable, Sendable {
    public let trip: Int
    public let day: ServiceDate
    public let seconds: Double

    public init(trip: Int, day: ServiceDate, seconds: Double) {
        self.trip = trip
        self.day = day
        self.seconds = seconds
    }
}

extension Service {
    public func runs(on day: ServiceDate) -> Bool {
        let number = day.number
        if removed.contains(number) { return false }
        if added.contains(number) { return true }
        guard start <= number, number <= end else { return false }
        return Array(weekdays).dropFirst(day.weekdayIndex).first == "1"
    }
}

extension Timetable {
    public static let shownBeforeDeparture = 600.0
    public static let shownAfterArrival = 90.0

    public func trips(on day: ServiceDate) -> [Int] {
        var seen: Set<String> = []
        return trips.indices.filter { index in
            let trip = trips[index]
            guard services[trip.service].runs(on: day), let first = trip.stops.first else { return false }
            return seen.insert("\(trip.code)|\(first.station)|\(first.departure)").inserted
        }
    }

    public func runningTrips(at date: Date) -> [RunningTrip] {
        let today = ServiceDate(date)
        return [today.adding(days: -1), today, today.adding(days: 1)].flatMap { day in
            let seconds = date.timeIntervalSince(day.timetableZero)
            return trips(on: day).compactMap { index -> RunningTrip? in
                let stops = trips[index].stops
                guard let first = stops.first, let last = stops.last,
                      seconds >= Double(first.departure) - Self.shownBeforeDeparture,
                      seconds <= Double(last.arrival) + Self.shownAfterArrival else { return nil }
                return RunningTrip(trip: index, day: day, seconds: seconds)
            }
        }
    }
}
