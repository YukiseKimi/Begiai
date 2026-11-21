import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Motion engine", .sealed, .timeLimit(.minutes(1)))
struct MotionEngineTests {
    struct Case: Decodable {
        let metres: Double
        let seconds: Double
        let elapsed: Double
        let covered: Double
    }

    struct Fixture: Decodable {
        let cases: [Case]
    }

    @Test func theSpeedProfileMatchesThePrototype() throws {
        let url = try #require(Bundle.module.url(forResource: "speed-profile", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        for item in fixture.cases {
            let covered = SpeedProfile.distance(length: item.metres, duration: item.seconds, elapsed: item.elapsed).metres
            #expect(abs(covered - item.covered) < 0.01, "\(item.metres) m in \(item.seconds) s at \(item.elapsed) s")
        }
    }

    @Test func aTrainNeverLeavesAStationBeforeItsDeparture() throws {
        let engine = MotionEngine(timetable: ThreeStops.timetable)
        let state = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 + 10 * 60 - 1)))
        #expect(state.phase == .atStation)
        #expect(state.metres == 50_000)
    }

    @Test func aTrainStandsAtAStationEvenWhenTheTimetableGivesOneTime() throws {
        let engine = MotionEngine(timetable: ThreeStops.timetable)
        let state = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 + 30 * 60 - 10)))
        #expect(state.phase == .atStation)
        #expect(state.lastStop == 2)
    }

    @Test func aRunningTrainIsBetweenItsTwoStations() throws {
        let engine = MotionEngine(timetable: ThreeStops.timetable)
        let state = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 + 5 * 60)))
        #expect(state.phase == .running)
        #expect(state.metres > 0 && state.metres < 50_000)
        #expect((state.lastStop, state.nextStop) == (0, 1))
    }

    @Test func aTrainOnAFastSectionDoesNotBorrowTimeToStand() throws {
        var timetable = ThreeStops.timetable
        timetable.trips[0].stops[2].arrival = 8 * 3600 + 13 * 60
        timetable.trips[0].stops[2].departure = 8 * 3600 + 13 * 60
        let engine = MotionEngine(timetable: timetable)
        let state = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 + 13 * 60 - 10)))
        #expect(state.phase == .running)
    }

    @Test func theMapShowsOnlyTrainsBetweenDepartureAndArrival() {
        let engine = MotionEngine(timetable: ThreeStops.timetable)
        let start = ThreeStops.day.timetableZero
        #expect(engine.trains(at: start.addingTimeInterval(8 * 3600 - 60)).isEmpty)
        #expect(engine.trains(at: start.addingTimeInterval(8 * 3600 + 60)).count == 1)
        #expect(engine.trains(at: start.addingTimeInterval(8 * 3600 + 40 * 60 + 1)).isEmpty)
    }
}

enum ThreeStops {
    static let day = ServiceDate(year: 2026, month: 11, day: 17)

    static var timetable: Timetable {
        let points = (0...4).map {
            ShapePoint(coordinate: Coordinate(latitude: 55, longitude: 24 + Double($0) * 0.4), metres: Double($0) * 25_000)
        }
        let stops = [
            TripStop(station: 0, arrival: 8 * 3600, departure: 8 * 3600, metres: 0),
            TripStop(station: 1, arrival: 8 * 3600 + 9 * 60, departure: 8 * 3600 + 10 * 60, metres: 50_000),
            TripStop(station: 2, arrival: 8 * 3600 + 30 * 60, departure: 8 * 3600 + 30 * 60, metres: 75_000),
            TripStop(station: 3, arrival: 8 * 3600 + 40 * 60, departure: 8 * 3600 + 40 * 60, metres: 100_000),
        ]
        return Timetable(
            feedDate: 20_261_117,
            stations: (0..<4).map { Station(name: "S\($0)", coordinate: points[$0].coordinate) },
            lines: [Line(name: "S0 – S3", ends: [0, 3], international: false)],
            shapes: [Shape(points: points)],
            trips: [Trip(id: "t", code: "1", line: 0, shape: 0, service: 0, stops: stops)],
            services: [Service(weekdays: "1111111", start: 20_260_101, end: 20_271_231, added: [], removed: [])])
    }
}
