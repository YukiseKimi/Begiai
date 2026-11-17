import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Train timeline", .sealed, .timeLimit(.minutes(1)))
struct TrainTimelineTests {
    let engine = MotionEngine(timetable: ThreeStops.timetable)

    @Test func betweenTwoStationsTheFirstIsPassedAndTheSecondIsNext() throws {
        let train = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 + 5 * 60)))
        let timeline = engine.timeline(of: train)
        #expect(timeline.stops.map(\.passed) == [true, false, false, false])
        #expect(timeline.nextStop == 1)
        #expect(timeline.progressToNext > 0 && timeline.progressToNext < 1)
    }

    @Test func atAStationTheTrainStandsThereAndTheNextComesAfter() throws {
        let train = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 + 9 * 60 + 30)))
        let timeline = engine.timeline(of: train)
        #expect(timeline.stops.map(\.passed) == [true, false, false, false])
        #expect(timeline.standingAt == 1)
        #expect(timeline.nextStop == 2)
        #expect(timeline.progressToNext == 0)
    }

    @Test func beforeDepartureNoStopIsPassed() throws {
        let train = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 - 60)))
        let timeline = engine.timeline(of: train)
        #expect(timeline.stops.map(\.passed) == [false, false, false, false])
        #expect(timeline.standingAt == 0)
    }

    @Test func afterTheLastArrivalEveryStopIsPassed() throws {
        let train = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 + 41 * 60)))
        let timeline = engine.timeline(of: train)
        #expect(timeline.stops.allSatisfy { $0.passed })
        #expect(timeline.nextStop == nil)
    }

    @Test func aStopWithOneTimetableTimeShowsTheArrivalTheMarkerUses() throws {
        let train = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 + 5 * 60)))
        let arrival = engine.timeline(of: train).stops[2].arrival
        #expect(
            Vilnius.calendar.dateComponents([.hour, .minute, .second], from: arrival) == DateComponents(hour: 8, minute: 29, second: 30))
    }

    @Test func theTimesAreTheTimetableTimesOfThatDay() throws {
        let train = try #require(engine.state(of: RunningTrip(trip: 0, day: ThreeStops.day, seconds: 8 * 3600 + 5 * 60)))
        let timeline = engine.timeline(of: train)
        let parts = Vilnius.calendar.dateComponents([.day, .hour, .minute], from: timeline.stops[1].departure)
        #expect(parts == DateComponents(day: 17, hour: 8, minute: 10))
        #expect((timeline.origin, timeline.destination) == ("S0", "S3"))
    }
}
