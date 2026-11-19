import XCTest

final class AboutJourney: XCTestCase {
    @MainActor
    func testAboutNamesItsSources() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        let about = AboutScreen(journey: journey)
        about.open()
        about.expectItsSourcesAndDate()
        about.close()
        MapScreen(journey: journey).expectLines()
        journey.holdLastScreen()
    }
}
