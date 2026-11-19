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

    @MainActor
    func testLargerMarkersStayOn() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)
        let before = map.trainWidth()

        let about = AboutScreen(journey: journey)
        about.open()
        about.largerMarkers().switches.firstMatch.tap()
        about.close()
        XCTAssertGreaterThan(map.trainWidth(), before * 1.25, "Map: the trains did not get larger")

        journey.relaunch()
        about.open()
        XCTAssertEqual(about.largerMarkers().value as? String, "1", "About: Larger markers is off after a relaunch")
        journey.holdLastScreen()
    }
}
