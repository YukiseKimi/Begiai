import XCTest

final class StarJourney: XCTestCase {
    @MainActor
    func testAStarredLineStaysStarredAfterARelaunch() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        let name = map.starTopLine()
        map.showStarred()
        map.expectOnlyLine(name)

        journey.relaunch(.map)
        map.showStarred()
        map.expectOnlyLine(name)
        journey.holdLastScreen()
    }

    @MainActor
    func testAStarredStationShowsItsNextTrainAboveTheLines() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)
        let board = BoardScreen(journey: journey)

        let station = map.openStationAboveThePanel()
        board.expectBoard(of: station)
        board.star()
        board.back()
        map.openStarredStation(station)
        board.expectBoard(of: station)
        journey.holdLastScreen()
    }
}
