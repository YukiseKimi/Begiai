import XCTest

final class StationJourney: XCTestCase {
    @MainActor
    func testATappedStationShowsItsNextDepartures() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        let station = MapScreen(journey: journey).openStationAboveThePanel()
        BoardScreen(journey: journey).expectBoard(of: station)
        journey.holdLastScreen()
    }
}
