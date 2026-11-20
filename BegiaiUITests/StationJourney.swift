import XCTest

final class StationJourney: XCTestCase {
    @MainActor
    func testATappedStationShowsItsNextDepartures() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        let station = MapScreen(journey: journey).openStationAboveThePanel()
        let board = BoardScreen(journey: journey)
        board.expectBoard(of: station)
        // The sealed time, 15:55 UTC, is 17:55 in Vilnius.
        board.expectMinutesWithinTheHour(now: (17, 55))
        journey.holdLastScreen()
    }

    @MainActor
    func testAStationUnderATrainStillOpensItsBoard() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)
        guard let station = MapScreen(journey: journey).openStationUnderATrain() else {
            XCTFail("Map: at 17:55 no train covers a station above the panel")
            return
        }
        BoardScreen(journey: journey).expectBoard(of: station)
        journey.holdLastScreen()
    }
}
