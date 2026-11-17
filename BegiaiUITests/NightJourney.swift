import XCTest

final class NightJourney: XCTestCase {
    @MainActor
    func testAtNightThePanelNamesTheFirstTrain() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map, at: "2026-11-17T00:30:00Z")

        MapScreen(journey: journey).expectFirstTrain()
        journey.holdLastScreen()
    }
}
