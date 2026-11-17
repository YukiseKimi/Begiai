import BegiaiKit
import BegiaiKitTestSupport
import BundleBuilder
import Foundation
import Testing

@Suite("Bundle builder", .sealed, .timeLimit(.minutes(1)))
struct BundleBuilderTests {
    @Test func aQuotedTripIDStillGetsItsStopTimes() throws {
        let feed = try SmallFeed(trips: [
            .init(id: "\"90_quoted\"", stops: [("A", "08:00:00"), ("C", "08:10:00")]),
        ]).write()
        let (timetable, _) = try BundleBuilder().build(feed: feed, feedDate: 20261117)
        #expect(timetable.trips.map(\.id) == ["90_quoted"])
    }

    @Test func eachStationSitsAtItsDistanceAlongTheTrack() throws {
        let feed = try SmallFeed(trips: [
            .init(id: "90_long", stops: [("A", "08:00:00"), ("B", "08:05:00"), ("C", "08:10:00")]),
        ]).write()
        let (timetable, report) = try BundleBuilder().build(feed: feed, feedDate: 20261117)
        let metres = timetable.trips[0].stops.map(\.metres)
        #expect(metres[0] == 0)
        #expect(abs(metres[1] - timetable.shapes[0].length / 2) < 5)
        #expect(abs(metres[2] - timetable.shapes[0].length) < 5)
        #expect(report.worstOffTrack < 5)
    }

    @Test func aRareShortTurnJoinsTheLineThatRunsThroughBothItsEnds() throws {
        let feed = try SmallFeed(trips: [
            .init(id: "90_long", stops: [("A", "08:00:00"), ("B", "08:05:00"), ("C", "08:10:00")]),
            .init(id: "90_short", stops: [("A", "09:00:00"), ("B", "09:05:00")]),
        ]).write()
        let (timetable, _) = try BundleBuilder().build(feed: feed, feedDate: 20261117)
        #expect(timetable.lines.map(\.name) == ["Alpha – Charlie"])
        #expect(Set(timetable.trips.map(\.line)) == [0])
    }

    @Test func aFrequentShortServiceKeepsItsOwnLine() throws {
        let shuttles = (0..<3).map { hour in
            SmallFeed.Trip(id: "90_shuttle\(hour)", stops: [("A", "1\(hour):00:00"), ("B", "1\(hour):05:00")])
        }
        let feed = try SmallFeed(trips: [
            .init(id: "90_long", stops: [("A", "08:00:00"), ("B", "08:05:00"), ("C", "08:10:00")]),
        ] + shuttles).write()
        let (timetable, _) = try BundleBuilder().build(feed: feed, feedDate: 20261117)
        #expect(Set(timetable.lines.map(\.name)) == ["Alpha – Charlie", "Alpha – Bravo"])
    }

    @Test func aTripThatRunsAgainstItsShapeStillBuilds() throws {
        let feed = try SmallFeed(trips: [
            .init(id: "90_back", stops: [("C", "08:00:00"), ("A", "08:10:00")]),
        ]).write()
        let (timetable, report) = try BundleBuilder().build(feed: feed, feedDate: 20261117)
        #expect(timetable.trips.count == 1)
        #expect(report.worstOffTrack.isFinite)
    }

    @Test func aFeedWithNoUsableTripsFailsInsteadOfWritingAnEmptyTimetable() throws {
        let feed = try SmallFeed(trips: [
            .init(id: "90_alone", stops: [("A", "08:00:00")]),
        ]).write()
        #expect(throws: BundleError.self) { try BundleBuilder().build(feed: feed, feedDate: 20261117) }
    }

    @Test func aStopWithNoTimesIsLeftOutInsteadOfFailingTheBundle() throws {
        let feed = try SmallFeed(trips: [
            .init(id: "90_pass", stops: [("A", "08:00:00"), ("B", ""), ("C", "08:10:00")]),
        ]).write()
        let (timetable, _) = try BundleBuilder().build(feed: feed, feedDate: 20261117)
        #expect(timetable.trips[0].stops.count == 2)
    }

    @Test func aFeedWithNoCalendarFails() throws {
        let feed = try SmallFeed(trips: [
            .init(id: "90_long", stops: [("A", "08:00:00"), ("C", "08:10:00")]),
        ]).write()
        try FileManager.default.removeItem(at: feed.appending(path: "calendar.txt"))
        try FileManager.default.removeItem(at: feed.appending(path: "calendar_dates.txt"))
        #expect(throws: BundleError.self) { try BundleBuilder().build(feed: feed, feedDate: 20261117) }
    }

    @Test func aSectionFasterThan160KilometresAnHourIsFlagged() throws {
        let feed = try SmallFeed(trips: [
            .init(id: "90_fast", stops: [("A", "08:00:00"), ("C", "08:01:00")]),
        ]).write()
        let (_, report) = try BundleBuilder().build(feed: feed, feedDate: 20261117)
        #expect(report.fastSections.count == 1)
    }
}

struct SmallFeed {
    struct Trip {
        let id: String
        let stops: [(String, String)]
    }

    let trips: [Trip]

    func write() throws -> URL {
        let folder = try #require(TestWorld.current).folder.appending(path: "feed", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let files: [String: [String]] = [
            "routes.txt": ["agency_id,route_id,route_short_name,route_type", "90,90_r,833,2", "7,7_bus,M1,3"],
            "trips.txt": ["route_id,service_id,trip_id,shape_id"]
                + trips.map { "90_r,s1,\($0.id),sh1" } + ["7_bus,s1,7_t,sh1"],
            "stop_times.txt": ["trip_id,stop_id,arrival_time,departure_time,stop_sequence"]
                + trips.flatMap { trip in
                    trip.stops.enumerated().map { "\(trip.id),\($1.0),\($1.1),\($1.1),\($0 + 1)" }
                } + ["7_t,A,08:00:00,08:00:00,1"],
            "stops.txt": ["stop_id,stop_name,stop_lat,stop_lon",
                          "A,Alpha,55.0,24.00", "B,Bravo,55.0,24.05", "C,Charlie,55.0,24.10"],
            "shapes.txt": ["shape_id,shape_pt_sequence,shape_pt_lat,shape_pt_lon"]
                + (0...20).map { "sh1,\($0),55.0,\(String(format: "%.3f", 24.0 + Double($0) * 0.005))" },
            "calendar.txt": ["service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date",
                             "s1,1,1,1,1,1,0,0,20261101,20270630"],
            "calendar_dates.txt": ["service_id,date,exception_type"],
        ]
        for (name, lines) in files {
            try (lines.joined(separator: "\r\n") + "\r\n").write(to: folder.appending(path: name), atomically: true, encoding: .utf8)
        }
        return folder
    }
}
