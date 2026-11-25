import XCTest

final class LaunchJourney: JourneyCase {
    @MainActor
    func testTheAppOpensOnTheMapWithItsRunningTrains() {
        let journey = JourneyApp()
        journey.launch(.map)

        TabsScreen(journey: journey).expectMapSelected()
        MapScreen(journey: journey).expectEveryCountedTrainOnTheMap()
    }

    @MainActor
    func testThePanelHandleSaysAndStepsItsHeight() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        map.expectPanel("Half")
        map.tapPanelHandle()
        map.expectPanel("Full")
        map.tapPanelHandle()
        map.expectPanel("Small")
    }

    @MainActor
    func testThePanelFollowsAFingerThatDragsItsHandle() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        map.expectPanel("Half")
        map.dragPanelHandle(toHeight: 0.1)
        map.expectPanel("Full")
        map.dragPanelHandle(toHeight: 0.9)
        map.expectPanel("Small")
    }
}
