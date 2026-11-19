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
}
