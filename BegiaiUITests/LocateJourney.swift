import XCTest

final class LocateJourney: XCTestCase {
    @MainActor
    func testLocationIsAskedOnlyAfterATapOnLocate() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.app.resetAuthorizationStatus(for: .location)
        journey.launch(.map)

        let map = MapScreen(journey: journey)
        map.expectNoLocationPrompt()
        map.tapLocate()
        map.expectLocationPrompt()
        journey.holdLastScreen()
    }
}
