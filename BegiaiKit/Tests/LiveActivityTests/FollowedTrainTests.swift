import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Followed train", .sealed, .timeLimit(.minutes(1)))
struct FollowedTrainTests {
    /// Vilnius 08:00 → Kaišiadorys 08:48–08:50 → Kaunas 09:22, on 17 Nov 2026.
    let train = Trains.vilniusKaunas

    @Test func beforeDepartureItBoardsAtItsFirstStop() {
        let place = train.place(at: Trains.at(7, 58))
        #expect(place == .boarding)
        #expect(train.passed(place) == 0)
        #expect(train.next(place)?.stop == 0)
        #expect(train.next(place)?.time == Trains.at(8, 0))
    }

    @Test func betweenStopsTheNextIsTheArrivalAhead() throws {
        let place = train.place(at: Trains.at(8, 20))
        #expect(place == .leaving(0))
        #expect(train.passed(place) == 1)
        let next = try #require(train.next(place))
        #expect(next.stop == 1)
        #expect(next.time == Trains.at(8, 48))
        #expect(!next.standing)
    }

    @Test func atAStopItStandsThereUntilItLeaves() throws {
        let place = train.place(at: Trains.at(8, 49))
        #expect(place == .at(1))
        #expect(train.passed(place) == 1)
        let next = try #require(train.next(place))
        #expect(next.stop == 1)
        #expect(next.time == Trains.at(8, 50))
        #expect(next.standing)
    }

    @Test func eachRunFillsItsPartOfTheBarFromItsDepartureToTheNextArrival() {
        #expect(train.runs == [Trains.at(8, 0)...Trains.at(8, 48), Trains.at(8, 50)...Trains.at(9, 22)])
        // 48 and 32 minutes of running: the time at Kaišiadorys takes no part of the bar.
        #expect(train.stopFractions() == [0, 0.6, 1])
    }

    @Test func aShortRunStillKeepsItsDotsApart() {
        let close = FollowedTrain(
            trip: "c", day: 20_261_117, line: "Vilnius – Kaunas", colour: 4,
            stops: [
                .init(name: "Vilnius", arrival: Trains.at(8, 0), departure: Trains.at(8, 0)),
                .init(name: "Paneriai", arrival: Trains.at(8, 1), departure: Trains.at(8, 1)),
                .init(name: "Kaunas", arrival: Trains.at(9, 40), departure: Trains.at(9, 40)),
            ])
        let fractions = close.stopFractions(minimumShare: 0.1)
        #expect(fractions.first == 0)
        #expect(fractions.last == 1)
        #expect(fractions[1] - fractions[0] >= 0.1)
        #expect(fractions[1] < 0.2)
        // A share too big for the runs splits the bar evenly.
        #expect(close.stopFractions(minimumShare: 0.9) == [0, 0.5, 1])
    }

    @Test func atTheLastArrivalTheTrainHasArrived() {
        let place = train.place(at: Trains.at(9, 22))
        #expect(place == .arrived)
        #expect(train.passed(place) == train.stops.count)
        #expect(train.next(place) == nil)
        #expect(train.hasArrived(at: Trains.at(9, 22)))
        #expect(!train.hasArrived(at: Trains.at(9, 21)))
    }

    @Test func aTrainOverMidnightKeepsItsServiceDayAndRunsIntoTheNextDate() throws {
        let night = try Trains.overMidnight()
        #expect(night.day == 20_261_117)
        let arrival = Vilnius.calendar.dateComponents([.day, .hour, .minute], from: night.arrival)
        #expect(arrival == DateComponents(day: 18, hour: 0, minute: 25))
        let afterMidnight = try #require(
            Vilnius.calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 0, minute: 5)))
        #expect(night.place(at: afterMidnight) == .leaving(1))
        #expect(night.next(night.place(at: afterMidnight))?.stop == 2)
        #expect(night.isTrain(trip: "night", day: ServiceDate(year: 2026, month: 11, day: 17)))
        #expect(!night.isTrain(trip: "night", day: ServiceDate(year: 2026, month: 11, day: 18)))
    }

    @Test func aShiftedTrainRunsOnTheDeviceClockFromThePinnedTime() {
        // A sealed launch pins 08:20; the device clock says 14:00, so the train runs on from there.
        let device = Trains.at(14, 0)
        let shifted = train.shifted(by: device.timeIntervalSince(Trains.at(8, 20)))
        #expect(shifted.status(at: device).place == .leaving(0))
        #expect(shifted.staleDate == Trains.at(15, 2))
        #expect(shifted.deviceRuns == [Trains.at(13, 40)...Trains.at(14, 28), Trains.at(14, 30)...Trains.at(15, 2)])
        #expect(FollowedTrain.stopFractions(of: shifted.deviceRuns) == train.stopFractions())
        #expect(shifted.nextChange(after: device) == Trains.at(14, 28))
        #expect(!shifted.hasArrived(at: Trains.at(15, 1)))
        #expect(shifted.hasArrived(at: Trains.at(15, 2)))
    }

    /// What the minutes countdown to Kaunas 09:22 reads at a time, as the Dynamic Island
    /// formats it: `dateRange(endingAt:)` gives the format `min(end, now)..<end`.
    func countdown(of train: FollowedTrain, at date: Date, _ seconds: TimeInterval = 0) -> String {
        let now = date.addingTimeInterval(seconds)
        return (min(train.countdownEnd, now)..<train.countdownEnd).formatted(Self.minutes)
    }

    static let minutes = Date.ComponentsFormatStyle(style: .narrow, locale: Locale(identifier: "en_US"), fields: [.hour, .minute])

    @Test func theCountdownReadsTheMinutesLeftAsTheClockDoes() {
        #expect(countdown(of: train, at: Trains.at(8, 47)) == "35m")
        #expect(countdown(of: train, at: Trains.at(8, 47), 50) == "35m")
        #expect(countdown(of: train, at: Trains.at(8, 16), 30) == "1h 6m")
        #expect(countdown(of: train, at: Trains.at(9, 21), 59) == "1m")
        #expect(countdown(of: train, at: Trains.at(9, 22)) == "0m")
        // A sealed launch shifts the train onto the device clock; the countdown follows it.
        let shifted = train.shifted(by: 3600)
        #expect(countdown(of: shifted, at: Trains.at(9, 47)) == "35m")
    }

    /// The widest reading of the countdown from a time on, which the island takes as its width.
    func widest(at date: Date, _ seconds: TimeInterval = 0) -> String {
        let now = date.addingTimeInterval(seconds)
        return (now..<now.addingTimeInterval(train.countdownWidest(at: now))).formatted(Self.minutes)
    }

    @Test func noReadingOfTheCountdownIsWiderThanItsWidest() {
        for start in [Trains.at(7, 0), Trains.at(8, 16), Trains.at(8, 47), Trains.at(9, 15), Trains.at(9, 21)] {
            for minute in stride(from: 0.0, through: train.countdownEnd.timeIntervalSince(start), by: 60) {
                let reading = countdown(of: train, at: start, minute)
                // The digits are as wide as each other, so the letters count the width.
                #expect(reading.count <= widest(at: start).count, "\(reading) is wider than \(widest(at: start))")
            }
        }
        #expect(widest(at: Trains.at(8, 16), 30) == "1h 59m")
        // Under an hour the minutes only fall, so the island is no wider than it needs.
        #expect(widest(at: Trains.at(8, 47), 50) == "35m")
        #expect(widest(at: Trains.at(9, 15)) == "7m")
    }

    @Test func anEndedActivityStaysAShortWhileAfterTheArrivalOnly() {
        // Ended on the way: the rider stopped following, so it goes at once.
        #expect(train.dismissal(at: Trains.at(9, 0)) == nil)
        #expect(train.dismissal(at: Trains.at(9, 22)) == Trains.at(9, 37))
        #expect(train.dismissal(at: Trains.at(9, 30)) == Trains.at(9, 37))
        #expect(train.dismissal(at: Trains.at(9, 37)) == nil)
    }

    @Test func theNextChangeIsTheNextArrivalOrDepartureUntilTheEnd() {
        #expect(train.nextChange(after: Trains.at(7, 0)) == Trains.at(8, 0))
        #expect(train.nextChange(after: Trains.at(8, 48)) == Trains.at(8, 50))
        #expect(train.nextChange(after: Trains.at(9, 22)) == nil)
    }

    @Test func theNewestRunningActivityIsKeptAndTheRestEnd() throws {
        let arrived = Trains.vilniusKaunas
        let older = try Trains.overMidnight()
        let newer = try Trains.overMidnight().shifted(by: 60)
        let review = FollowReview(activities: [arrived, older, newer], at: Trains.at(23, 50))
        #expect(review.followed == newer)
        #expect(review.ended == [0, 1])
        let none = FollowReview(activities: [arrived], at: Trains.at(23, 50))
        #expect(none.followed == nil)
        #expect(none.ended == [0])
    }

    @Test func aLongTrainFitsTheLiveActivityLimit() throws {
        let stops = (0..<30).map { k in
            FollowedTrain.Stop(
                name: "Kaišiadorys \(k)", arrival: Trains.at(8, 0).addingTimeInterval(Double(k) * 600),
                departure: Trains.at(8, 1).addingTimeInterval(Double(k) * 600))
        }
        let long = FollowedTrain(
            trip: "1234567890-abcdef", day: 20_261_117, line: "Vilnius – Klaipėda", colour: 3, stops: stops)
        let attributes = try JSONEncoder().encode(long)
        let status = try JSONEncoder().encode(long.status(at: Trains.at(9, 0)))
        // ActivityKit refuses a Live Activity whose data is over 4 KB.
        #expect(attributes.count + status.count < 4096)
        #expect(try JSONDecoder().decode(FollowedTrain.self, from: attributes) == long)
    }
}

enum Trains {
    static func at(_ hour: Int, _ minute: Int) -> Date {
        Vilnius.calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: hour, minute: minute))!
    }

    static let vilniusKaunas = FollowedTrain(
        trip: "vk", day: 20_261_117, line: "Vilnius – Kaunas", colour: 4,
        stops: [
            .init(name: "Vilnius", arrival: at(8, 0), departure: at(8, 0)),
            .init(name: "Kaišiadorys", arrival: at(8, 48), departure: at(8, 50)),
            .init(name: "Kaunas", arrival: at(9, 22), departure: at(9, 22)),
        ])

    /// One trip, "night": 23:40 from S0, past midnight into S2 at 00:25, every day in 2026 and 2027.
    static var nightTimetable: Timetable {
        let points = (0...2).map {
            ShapePoint(coordinate: Coordinate(latitude: 55, longitude: 24 + Double($0) * 0.4), metres: Double($0) * 25_000)
        }
        let stops = [
            TripStop(station: 0, arrival: 23 * 3600 + 40 * 60, departure: 23 * 3600 + 40 * 60, metres: 0),
            TripStop(station: 1, arrival: 23 * 3600 + 58 * 60, departure: 24 * 3600, metres: 25_000),
            TripStop(station: 2, arrival: 24 * 3600 + 25 * 60, departure: 24 * 3600 + 25 * 60, metres: 50_000),
        ]
        return Timetable(
            feedDate: 20_261_117,
            stations: (0..<3).map { Station(name: "S\($0)", coordinate: points[$0].coordinate) },
            lines: [Line(name: "S0 – S2", ends: [0, 2], international: false)],
            shapes: [Shape(points: points)],
            trips: [Trip(id: "night", code: "9", line: 0, shape: 0, service: 0, stops: stops)],
            services: [Service(weekdays: "1111111", start: 20_260_101, end: 20_271_231, added: [], removed: [])])
    }

    /// The night train of 17 Nov, built through the motion engine, as the app builds it.
    static func overMidnight() throws -> FollowedTrain {
        let engine = MotionEngine(timetable: nightTimetable)
        let day = ServiceDate(year: 2026, month: 11, day: 17)
        let state = try #require(engine.state(of: RunningTrip(trip: 0, day: day, seconds: 23 * 3600 + 45 * 60)))
        return FollowedTrain(timeline: engine.timeline(of: state), trip: "night", day: day, line: "S0 – S2", colour: 0)
    }
}

extension FollowedTrain {
    func shifted(by shift: TimeInterval) -> FollowedTrain {
        FollowedTrain(trip: trip, day: day, line: line, colour: colour, stops: stops, shift: shift)
    }
}
