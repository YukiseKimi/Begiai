import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Line summaries", .sealed, .timeLimit(.minutes(1)))
struct LineSummaryTests {
    @Test func theBusiestLineComesFirstAndAStarredLineBeforeIt() {
        let engine = MotionEngine(timetable: TwoLines.timetable)
        let date = TwoLines.day.timetableZero.addingTimeInterval(8 * 3600 + 60)
        let trains = engine.trains(at: date)
        #expect(engine.lineSummaries(at: date, trains: trains).map(\.name) == ["Busy", "Quiet"])
        #expect(engine.lineSummaries(at: date, trains: trains, starred: ["Quiet"]).map(\.name) == ["Quiet", "Busy"])
    }

    @Test func eachLineCountsItsOwnRunningTrains() {
        let engine = MotionEngine(timetable: TwoLines.timetable)
        let date = TwoLines.day.timetableZero.addingTimeInterval(8 * 3600 + 60)
        let summaries = engine.lineSummaries(at: date, trains: engine.trains(at: date))
        #expect(summaries.map(\.trainsNow) == [2, 1])
        #expect(summaries.map(\.tripsToday) == [3, 1])
    }

    @Test func eachFilterKeepsOnlyItsLines() {
        let engine = MotionEngine(timetable: TwoLines.timetable)
        let date = TwoLines.day.timetableZero.addingTimeInterval(8 * 3600 + 60)
        let summaries = engine.lineSummaries(at: date, trains: engine.trains(at: date))
        let names = { (filter: LineFilter, starred: Set<String>) in summaries.filter { filter.includes($0, starred: starred) }.map(\.name) }
        #expect(names(.all, []) == ["Busy", "Quiet"])
        #expect(names(.international, []) == ["Busy"])
        #expect(names(.starred, ["Quiet"]) == ["Quiet"])
    }

    @Test func aTripWithAnUnknownLineIsLeftOutOfTheCounts() {
        var timetable = TwoLines.timetable
        timetable.trips[0].line = 9
        let engine = MotionEngine(timetable: timetable)
        let date = TwoLines.day.timetableZero.addingTimeInterval(8 * 3600 + 60)
        #expect(engine.lineSummaries(at: date, trains: engine.trains(at: date)).map(\.trainsNow).reduce(0, +) == 2)
    }
}

enum TwoLines {
    static let day = ServiceDate(year: 2026, month: 11, day: 17)

    static var timetable: Timetable {
        let a = Coordinate(latitude: 55, longitude: 24)
        let b = Coordinate(latitude: 55, longitude: 25)
        func trip(_ id: String, line: Int, departs: Int) -> Trip {
            Trip(
                id: id, code: id, line: line, shape: 0, service: 0,
                stops: [
                    TripStop(station: 0, arrival: departs, departure: departs, metres: 0),
                    TripStop(station: 1, arrival: departs + 3600, departure: departs + 3600, metres: 64_000),
                ])
        }
        return Timetable(
            feedDate: 20_261_117,
            stations: [Station(name: "A", coordinate: a), Station(name: "B", coordinate: b)],
            lines: [Line(name: "Quiet", ends: [0, 1], international: false), Line(name: "Busy", ends: [0, 1], international: true)],
            shapes: [Shape(points: [ShapePoint(coordinate: a, metres: 0), ShapePoint(coordinate: b, metres: 64_000)])],
            trips: [
                trip("q1", line: 0, departs: 8 * 3600), trip("b1", line: 1, departs: 8 * 3600),
                trip("b2", line: 1, departs: 7 * 3600 + 30 * 60), trip("b3", line: 1, departs: 18 * 3600),
            ],
            services: [Service(weekdays: "1111111", start: 20_260_101, end: 20_271_231, added: [], removed: [])])
    }
}
