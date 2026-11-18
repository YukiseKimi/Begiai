import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Line diagram", .sealed, .timeLimit(.minutes(1)))
struct LineDiagramTests {
    let engine = MotionEngine(timetable: FourStations.timetable)
    let zero = FourStations.day.timetableZero

    @Test func theStationsOfAllTripsMakeOneOrderFromTheFirstEnd() {
        let diagram = LineDiagram(line: 0, timetable: FourStations.timetable)
        #expect(diagram.stations == [0, 1, 2, 3])
    }

    @Test func aTrainTowardTheLastEndRunsDownBetweenItsTwoStations() throws {
        let train = try #require(engine.trains(at: zero.addingTimeInterval(8 * 3600 + 15 * 60)).first { $0.trip == 0 })
        let place = try #require(LineDiagram(line: 0, timetable: FourStations.timetable).place(of: train))
        #expect(place.from == 1 && place.to == 2)
        #expect(place.direction == .down)
        #expect(place.fraction > 0 && place.fraction < 1)
        #expect(place.row > 1 && place.row < 2)
    }

    @Test func anExpressTowardTheFirstEndRunsUpAndSkipsTheStationItDoesNotStopAt() throws {
        let train = try #require(engine.trains(at: zero.addingTimeInterval(9 * 3600 + 30 * 60)).first { $0.trip == 1 })
        let place = try #require(LineDiagram(line: 0, timetable: FourStations.timetable).place(of: train))
        #expect(place.from == 2 && place.to == 0)
        #expect(place.direction == .up)
        #expect(place.row > 0 && place.row < 2)
    }

    @Test func aTrainAtAStationStandsOnItsRow() throws {
        let train = try #require(engine.trains(at: zero.addingTimeInterval(8 * 3600 + 10 * 60 + 30)).first { $0.trip == 0 })
        let place = try #require(LineDiagram(line: 0, timetable: FourStations.timetable).place(of: train))
        #expect(place.row == 1)
    }

    @Test func aTrainOfAnotherLineHasNoPlace() throws {
        let train = try #require(engine.trains(at: zero.addingTimeInterval(8 * 3600 + 15 * 60)).first { $0.trip == 0 })
        #expect(LineDiagram(line: 1, timetable: FourStations.timetable).place(of: train) == nil)
    }
}

/// Vilnius, A, B and Kaunas from west to east. A stopping train runs down, an express runs up
/// without A, and a short train of another line runs from A to B.
enum FourStations {
    static let day = ServiceDate(year: 2026, month: 11, day: 17)

    static var timetable: Timetable {
        let points = (0...3).map { ShapePoint(coordinate: Coordinate(latitude: 55, longitude: 24 + Double($0) * 0.4), metres: Double($0) * 25_000) }
        func stop(_ station: Int, _ minutes: Int, dwell: Int = 0) -> TripStop {
            TripStop(station: station, arrival: 8 * 3600 + minutes * 60, departure: 8 * 3600 + (minutes + dwell) * 60, metres: Double(station) * 25_000)
        }
        func back(_ station: Int, _ minutes: Int) -> TripStop {
            TripStop(station: station, arrival: 9 * 3600 + minutes * 60, departure: 9 * 3600 + minutes * 60, metres: Double(3 - station) * 25_000)
        }
        let reversed = Shape(points: points.reversed().enumerated().map { ShapePoint(coordinate: $1.coordinate, metres: Double($0) * 25_000) })
        return Timetable(
            feedDate: 20261117,
            stations: ["Vilnius", "A", "B", "Kaunas"].enumerated().map { Station(name: $1, coordinate: points[$0].coordinate) },
            lines: [
                Line(name: "Vilnius – Kaunas", ends: [0, 3], international: false),
                Line(name: "A – B", ends: [1, 2], international: false),
            ],
            shapes: [Shape(points: points), reversed],
            trips: [
                Trip(id: "stopping", code: "1", line: 0, shape: 0, service: 0, stops: [stop(0, 0), stop(1, 10, dwell: 1), stop(2, 20), stop(3, 30)]),
                Trip(id: "express", code: "2", line: 0, shape: 1, service: 0, stops: [back(3, 0), back(2, 20), back(0, 50)]),
                Trip(id: "short", code: "3", line: 1, shape: 0, service: 0, stops: [stop(1, 0), stop(2, 10)]),
            ],
            services: [Service(weekdays: "1111111", start: 20260101, end: 20271231, added: [], removed: [])])
    }
}

@Suite("A chosen train", .sealed, .timeLimit(.minutes(1)))
struct ChosenTrainTests {
    let engine = MotionEngine(timetable: FourStations.timetable)
    let zero = FourStations.day.timetableZero

    @Test func aTrainFoundByItsIDMovesOnUntilItArrives() throws {
        let id = try #require(engine.trains(at: zero.addingTimeInterval(8 * 3600 + 15 * 60)).first { $0.trip == 0 }).id
        let later = try #require(engine.train(id, at: zero.addingTimeInterval(8 * 3600 + 25 * 60)))
        #expect(later.lastStop == 2)
        #expect(engine.train(id, at: zero.addingTimeInterval(8 * 3600 + 31 * 60)) == nil)
    }
}
