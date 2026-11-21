import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Service day", .sealed, .timeLimit(.minutes(1)))
struct ServiceDayTests {
    let tuesday = ServiceDate(year: 2026, month: 11, day: 17)

    @Test func aTripPastMidnightRunsOnTheServiceDayItStarted() throws {
        let timetable = TinyTimetable.make(trips: [("late", "1111111", 23 * 3600 + 50 * 60, 24 * 3600 + 40 * 60)])
        let twentyPastMidnight = tuesday.adding(days: 1).midnight.addingTimeInterval(20 * 60)
        let running = timetable.runningTrips(at: twentyPastMidnight)
        #expect(running == [RunningTrip(trip: 0, day: tuesday, seconds: 24 * 3600 + 20 * 60)])
    }

    @Test func onTheNightTheClocksGoBackATrainStillLeavesAtItsTimetableTime() {
        let clocksBack = ServiceDate(year: 2026, month: 10, day: 25)
        let timetable = TinyTimetable.make(trips: [("morning", "1111111", 10 * 3600, 11 * 3600)])
        let tenOClock = Vilnius.calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 10))!
        let running = timetable.runningTrips(at: tenOClock).first { $0.day == clocksBack }
        #expect(abs((running?.seconds ?? 0) - 10 * 3600) < 0.001)
    }

    @Test func aRemovedDateStopsTheService() {
        let timetable = TinyTimetable.make(trips: [("daily", "1111111", 8 * 3600, 9 * 3600)], removed: [tuesday.number])
        #expect(timetable.trips(on: tuesday).isEmpty)
        #expect(timetable.trips(on: tuesday.adding(days: 1)) == [0])
    }

    @Test func aDuplicatedTripRunsOnce() {
        let timetable = TinyTimetable.make(trips: [("a", "1111111", 8 * 3600, 9 * 3600), ("b", "1111111", 8 * 3600, 9 * 3600)])
        #expect(timetable.trips(on: tuesday) == [0])
    }

    @Test func theEngineAgreesWithTheTimetableHourByHourThroughAWeekAndBack() {
        let timetable = TinyTimetable.make(trips: [
            ("weekday", "1111100", 8 * 3600, 9 * 3600), ("late", "1111111", 23 * 3600 + 30 * 60, 24 * 3600 + 50 * 60),
            ("sunday", "0000001", 12 * 3600, 13 * 3600),
        ])
        let engine = MotionEngine(timetable: timetable)
        let hours = Array(0..<(8 * 24)) + (0..<(8 * 24)).reversed()
        for hour in hours {
            let date = tuesday.midnight.addingTimeInterval(Double(hour) * 3600 + 15 * 60)
            let expected = timetable.runningTrips(at: date, until: { engine.schedule(of: $0).arrivals.last ?? 0 })
            #expect(engine.trains(at: date).map { "\($0.trip)@\($0.day)" } == expected.map { "\($0.trip)@\($0.day)" })
            let today = timetable.trips(on: ServiceDate(date)).count
            #expect(engine.lineSummaries(at: date, trains: []).map(\.tripsToday).reduce(0, +) == today)
        }
    }

    @Test func aWeekdayServiceDoesNotRunOnSunday() {
        let timetable = TinyTimetable.make(trips: [("weekday", "1111100", 8 * 3600, 9 * 3600)])
        #expect(timetable.trips(on: tuesday) == [0])
        #expect(timetable.trips(on: ServiceDate(year: 2026, month: 11, day: 22)).isEmpty)
    }
}

enum TinyTimetable {
    static func make(trips: [(id: String, weekdays: String, departure: Int, arrival: Int)], removed: [Int] = []) -> Timetable {
        let a = Coordinate(latitude: 54.67, longitude: 25.28)
        let b = Coordinate(latitude: 54.90, longitude: 23.90)
        return Timetable(
            feedDate: 20_261_117,
            stations: [Station(name: "Vilnius", coordinate: a), Station(name: "Kaunas", coordinate: b)],
            lines: [Line(name: "Vilnius – Kaunas", ends: [0, 1], international: false)],
            shapes: [Shape(points: [ShapePoint(coordinate: a, metres: 0), ShapePoint(coordinate: b, metres: 100_000)])],
            trips: trips.enumerated().map { index, trip in
                Trip(
                    id: trip.id, code: "833", line: 0, shape: 0, service: index,
                    stops: [
                        TripStop(station: 0, arrival: trip.departure, departure: trip.departure, metres: 0),
                        TripStop(station: 1, arrival: trip.arrival, departure: trip.arrival, metres: 100_000),
                    ])
            },
            services: trips.map { Service(weekdays: $0.weekdays, start: 20_260_101, end: 20_271_231, added: [], removed: removed) }
        )
    }
}
