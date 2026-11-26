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

/// A trip of a service day, and how far into that day the moment is.
struct RunningTrip: Equatable, Sendable {
    let trip: Int
    let day: ServiceDate
    let seconds: Double
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

private struct DuplicateKey: Hashable {
    let code: String
    let station: Int
    let departure: Int
}

extension Timetable {
    public func trips(on day: ServiceDate) -> [Int] {
        var seen: Set<DuplicateKey> = []
        return trips.indices.filter { index in
            let trip = trips[index]
            guard trip.stops.count >= 2, services[trip.service].runs(on: day) else { return false }
            return seen.insert(DuplicateKey(code: trip.code, station: trip.stops[0].station, departure: trip.stops[0].departure)).inserted
        }
    }

    func runningTrips(at date: Date, until end: (Int) -> Double, days: (ServiceDate) -> ServiceDay) -> [RunningTrip] {
        let today = ServiceDate(date)
        return [today.adding(days: -1), today].flatMap { service in
            let day = days(service)
            let seconds = date.timeIntervalSince(day.zero)
            return day.trips.compactMap { index -> RunningTrip? in
                let stops = trips[index].stops
                guard seconds >= Double(stops[0].departure),
                    seconds < max(Double(stops[stops.count - 1].arrival), end(index))
                else { return nil }
                return RunningTrip(trip: index, day: day.date, seconds: seconds)
            }
        }
    }
}
