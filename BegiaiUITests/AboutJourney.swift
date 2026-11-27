import StoreKitTest
import XCTest

final class AboutJourney: JourneyCase {
    @MainActor
    func testAboutNamesItsSources() {
        let journey = JourneyApp()
        journey.launch(.map)

        let about = AboutScreen(journey: journey)
        about.open()
        about.expectItsSourcesAndDate()
        about.close()
        MapScreen(journey: journey).expectLines()
    }

    @MainActor
    func testATipSaysThankYou() async throws {
        // The local StoreKit file: no real money, and no confirmation sheet.
        let store = try SKTestSession(configurationFileNamed: "Begiai")
        try await skipUnlessStoreKitTakesTheSession(store)
        store.disableDialogs = true
        store.clearTransactions()
        let journey = JourneyApp()
        journey.launch(.map)

        let about = AboutScreen(journey: journey)
        about.open()
        about.tipACoffee()
    }

    @MainActor
    func testLargerMarkersStayOn() {
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
    }

    /// The probe: it sets a simulated StoreKit error and reads it back, then clears it. When
    /// storekitd did not keep the error, the SKTestSession is not in force: the app would ask the
    /// real Sandbox store, and the tip rows would stay empty. The tip test then skips and says so.
    /// The known cause: on iOS 26.3–26.5 with Xcode 27.2, storekitd turns down every test-session
    /// call from the UI-test runner and logs "UITests.xctrunner is not installed for development",
    /// yet the calls do not throw. A simulator fault, not an app fault.
    private func skipUnlessStoreKitTakesTheSession(_ store: SKTestSession) async throws {
        let probe = SKTestFailures.LoadProducts.generic(.unknown)
        try await store.setSimulatedError(probe, forAPI: .loadProducts)
        let kept = await store.simulatedError(forAPI: .loadProducts)
        try await store.setSimulatedError(nil, forAPI: .loadProducts)
        if kept != probe {
            throw XCTSkip(
                """
                storekitd did not keep a simulated StoreKit error, so the SKTestSession is not in force \
                and the app would ask the real Sandbox store. Known cause: on iOS 26.3–26.5 with Xcode \
                27.2, storekitd logs "UITests.xctrunner is not installed for development".
                """)
        }
    }
}
