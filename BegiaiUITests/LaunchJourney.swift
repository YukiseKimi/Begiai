import XCTest

final class LaunchJourney: XCTestCase {
    @MainActor
    func testTheAppOpensOnTheMapWithItsRunningTrains() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        TabsScreen(journey: journey).expectMapSelected()
        MapScreen(journey: journey).expectEveryCountedTrainOnTheMap()
        journey.holdLastScreen()
    }

    @MainActor
    func testThePanelHandleSaysAndStepsItsHeight() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        map.expectPanel("Half")
        map.tapPanelHandle()
        map.expectPanel("Full")
        map.tapPanelHandle()
        map.expectPanel("Small")
        journey.holdLastScreen()
    }
}
