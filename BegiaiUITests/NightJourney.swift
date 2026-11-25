import XCTest

final class NightJourney: JourneyCase {
    @MainActor
    func testAtNightThePanelNamesTheFirstTrain() {
        let journey = JourneyApp()
        journey.launch(.map, at: "2026-11-17T00:30:00Z")

        MapScreen(journey: journey).expectFirstTrain()
    }
}
