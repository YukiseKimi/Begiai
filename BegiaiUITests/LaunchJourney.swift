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
}
