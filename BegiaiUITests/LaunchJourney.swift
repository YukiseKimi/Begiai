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
    func testThePanelHandleSaysAndStepsItsHeight() throws {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)
        try XCTSkipIf(map.hasColumn(), "Duo: the column has no heights to step or drag; it stays at the screen's full height")

        map.expectPanel("Half")
        map.tapPanelHandle()
        map.expectPanel("Full")
        map.tapPanelHandle()
        map.expectPanel("Small")
    }

    @MainActor
    func testThePanelFollowsAFingerThatDragsItsHandle() throws {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)
        try XCTSkipIf(map.hasColumn(), "Duo: the column has no heights to step or drag; it stays at the screen's full height")

        map.expectPanel("Half")
        map.dragPanelHandle(toHeight: 0.1)
        map.expectPanel("Full")
        map.dragPanelHandle(toHeight: 0.9)
        map.expectPanel("Small")
    }
}
