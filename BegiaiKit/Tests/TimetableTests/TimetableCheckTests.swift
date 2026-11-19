import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Timetable check", .sealed, .timeLimit(.minutes(1)))
struct TimetableCheckTests {
    @Test func theShippedTimetablePasses() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../Begiai/timetable.json").standardizedFileURL
        try JSONDecoder().decode(Timetable.self, from: Data(contentsOf: url)).check()
    }

    @Test func aStopAtAStationThatIsNotThereFails() {
        var timetable = FourStations.timetable
        timetable.trips[0].stops[1].station = 9
        #expect(throws: TimetableProblem.outOfRange("the stops of trip stopping")) { try timetable.check() }
    }

    @Test func aTimetableWithNoTripOnItsFeedDateFails() {
        var timetable = FourStations.timetable
        timetable.feedDate = 20250101
        #expect(throws: TimetableProblem.noServiceOnFeedDate(20250101)) { try timetable.check() }
    }

    @Test func aManifestNamesOnlyItsOwnBundle() {
        let bundle = Data("{\"feedDate\":1}".utf8)
        let manifest = Manifest(bundle: bundle, feedDate: 20261117)
        #expect(manifest.format == Timetable.format)
        #expect(manifest.names(bundle))
        #expect(!manifest.names(Data("{\"feedDate\":2}".utf8)))
    }
}

@Suite("Service date from a number", .sealed, .timeLimit(.minutes(1)))
struct ServiceDateNumberTests {
    @Test func aRealDateReadsBackAndAnImpossibleOneDoesNot() {
        #expect(ServiceDate(number: 20261117) == ServiceDate(year: 2026, month: 11, day: 17))
        #expect(ServiceDate(number: 20260231) == nil)
        #expect(ServiceDate(number: 20261300) == nil)
    }
}
