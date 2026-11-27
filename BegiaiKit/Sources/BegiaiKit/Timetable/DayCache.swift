import Foundation
import Synchronization

/// What the engine needs to know about one service day, worked out once for that day.
struct ServiceDay: Sendable {
    let date: ServiceDate
    let zero: Date
    let trips: [Int]
    let tripsPerLine: [Int]
}

/// Keeps the last few service days, so a frame does not filter every trip again.
final class DayCache: Sendable {
    private static let kept = 4
    private let days = Mutex<[ServiceDay]>([])

    func day(_ date: ServiceDate, in timetable: Timetable) -> ServiceDay {
        if let day = days.withLock({ $0.first { $0.date == date } }) { return day }
        let trips = timetable.trips(on: date)
        var perLine = Array(repeating: 0, count: timetable.lines.count)
        for trip in trips where perLine.indices.contains(timetable.trips[trip].line) {
            perLine[timetable.trips[trip].line] += 1
        }
        let day = ServiceDay(date: date, zero: date.timetableZero, trips: trips, tripsPerLine: perLine)
        days.withLock { days in
            guard !days.contains(where: { $0.date == date }) else { return }
            days.append(day)
            if days.count > Self.kept { days.removeFirst() }
        }
        return day
    }
}
