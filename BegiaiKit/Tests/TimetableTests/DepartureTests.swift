import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Departures", .sealed, .timeLimit(.minutes(1)))
struct DepartureTests {
    let engine = MotionEngine(timetable: ThreeStops.timetable)

    @Test func aBoardListsOnlyTrainsThatHaveNotLeft() {
        let afterFirst = ThreeStops.day.timetableZero.addingTimeInterval(8 * 3600 + 11 * 60)
        #expect(engine.departures(from: 1, at: afterFirst).first?.time != nil)
        let beforeNext = engine.departures(from: 1, at: afterFirst).first?.time ?? .distantPast
        #expect(beforeNext > afterFirst)
    }

    @Test func theFirstStationSaysStartsHereAndTheLastHasNoDepartures() {
        let early = ThreeStops.day.timetableZero.addingTimeInterval(7 * 3600)
        #expect(engine.departures(from: 0, at: early).first?.startsHere == true)
        #expect(engine.departures(from: 1, at: early).first?.startsHere == false)
        #expect(engine.departures(from: 3, at: early).isEmpty)
    }

    @Test func lateAtNightTheBoardShowsTomorrowsTrains() {
        let late = ThreeStops.day.timetableZero.addingTimeInterval(23 * 3600)
        let next = engine.departures(from: 0, at: late).first
        #expect(next?.id.day == ThreeStops.day.adding(days: 1))
        #expect(next?.tomorrow == true)
        #expect(next?.destination == "S3")
    }

    @Test func twoBusyStationsCloseTogetherGiveOneBigMarker() {
        var timetable = ThreeStops.timetable
        timetable.stations[1].coordinate = Coordinate(latitude: 55, longitude: 24.05)
        timetable.trips += Array(repeating: timetable.trips[0], count: 12)
        let big = MotionEngine(timetable: timetable).bigStations()
        #expect(big.contains(0) != big.contains(1))
        #expect(big.contains(3))
    }

    @Test func aTripThatCallsTwiceShowsItsLaterCall() {
        var timetable = ThreeStops.timetable
        timetable.trips[0].stops[2].station = 1
        let engine = MotionEngine(timetable: timetable)
        let between = ThreeStops.day.timetableZero.addingTimeInterval(8 * 3600 + 20 * 60)
        let next = engine.departures(from: 1, at: between).first
        #expect(next?.id.stop == 2)
        #expect(next?.tomorrow == false)
    }
}
