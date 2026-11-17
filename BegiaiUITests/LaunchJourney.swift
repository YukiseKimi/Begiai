import XCTest

final class LaunchJourney: XCTestCase {
    @MainActor
    func testTheAppOpensOnTheMap() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        TabsScreen(journey: journey).expectMapSelected()
        journey.holdLastScreen()
    }
}
