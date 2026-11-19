import StoreKitTest
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

    @MainActor
    func testATipSaysThankYou() throws {
        continueAfterFailure = false
        // The local StoreKit file: no real money, and no confirmation sheet.
        let store = try SKTestSession(configurationFileNamed: "Begiai")
        store.disableDialogs = true
        store.clearTransactions()
        let journey = JourneyApp()
        journey.launch(.map)

        let about = AboutScreen(journey: journey)
        about.open()
        about.tipACoffee()
        journey.holdLastScreen()
    }
}
