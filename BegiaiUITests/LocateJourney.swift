import XCTest

final class LocateJourney: JourneyCase {
    @MainActor
    func testLocationIsAskedOnlyAfterATapOnLocate() {
        let journey = JourneyApp()
        journey.app.resetAuthorizationStatus(for: .location)
        journey.launch(.map)

        let map = MapScreen(journey: journey)
        map.expectNoLocationPrompt()
        map.tapLocate()
        map.expectLocationPrompt()
    }
}
