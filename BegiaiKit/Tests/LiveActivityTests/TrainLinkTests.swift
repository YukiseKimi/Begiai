import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Train link", .sealed, .timeLimit(.minutes(1)))
struct TrainLinkTests {
    let day = ServiceDate(year: 2026, month: 11, day: 17)

    @Test func aLinkCarriesItsTripAndDayThere() throws {
        let link = TrainLink(trip: "night", day: day)
        #expect(link.url.absoluteString == "begiai://train?trip=night&day=20261117")
        #expect(TrainLink(url: link.url) == link)
    }

    @Test func aTripIdWithSignsInItComesBackTheSame() throws {
        let link = TrainLink(trip: "LG 1234/a&b=c d", day: day)
        #expect(TrainLink(url: link.url) == link)
    }

    @Test(arguments: [
        "https://train?trip=night&day=20261117",
        "begiai://station?trip=night&day=20261117",
        "begiai://train?day=20261117",
        "begiai://train?trip=&day=20261117",
        "begiai://train?trip=night",
        "begiai://train?trip=night&day=20261341",
        "begiai://train?trip=night&day=20260230",
        "begiai://train?trip=night&day=tomorrow",
    ])
    func aLinkThatIsNotATrainsReadsAsNone(text: String) throws {
        #expect(TrainLink(url: try #require(URL(string: text))) == nil)
    }

    @Test func theFollowedTrainLinksToItself() throws {
        let train = try Trains.overMidnight()
        #expect(train.link == TrainLink(trip: "night", day: day))
    }

    @Test func aLinkOpensItsTrainWhileItRuns() throws {
        let engine = MotionEngine(timetable: Trains.nightTimetable)
        let link = TrainLink(trip: "night", day: day)
        let train = try #require(engine.train(for: link, at: Trains.at(23, 50)))
        #expect(train.trip == 0)
        #expect(train.day == day)
    }

    @Test func aLinkToATrainThatHasArrivedOrNeverRunsOpensNone() throws {
        let engine = MotionEngine(timetable: Trains.nightTimetable)
        let arrived = try #require(Vilnius.calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 0, minute: 30)))
        #expect(engine.train(for: TrainLink(trip: "night", day: day), at: arrived) == nil)
        #expect(engine.train(for: TrainLink(trip: "gone", day: day), at: Trains.at(23, 50)) == nil)
        // The service runs in 2026 and 2027 only.
        let later = ServiceDate(year: 2028, month: 11, day: 17)
        #expect(
            engine.train(for: TrainLink(trip: "night", day: later), at: later.timetableZero.addingTimeInterval(23 * 3600 + 50 * 60)) == nil)
    }
}
