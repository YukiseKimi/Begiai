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
}
