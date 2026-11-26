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

    /// Some simulator runtimes (iOS 26.3, 26.4 and 26.5 with Xcode 27.2) turn down every
    /// test-session call from the UI-test runner: storekitd logs "…UITests.xctrunner is not
    /// installed for development", yet the calls do not throw. The app then asks the real Sandbox
    /// store, and the tip rows stay empty. That is a simulator fault, not an app fault, so the
    /// tip test skips and names it. The probe: a simulated error that storekitd keeps reads back,
    /// and one it turned down does not. It is cleared again before the test goes on.
    private func skipUnlessStoreKitTakesTheSession(_ store: SKTestSession) async throws {
        let probe = SKTestFailures.LoadProducts.generic(.unknown)
        try await store.setSimulatedError(probe, forAPI: .loadProducts)
        let kept = await store.simulatedError(forAPI: .loadProducts)
        try await store.setSimulatedError(nil, forAPI: .loadProducts)
        if kept != probe {
            throw XCTSkip(
                """
                StoreKit testing is off on this simulator: storekitd turned down the SKTestSession \
                ("UITests.xctrunner is not installed for development"), so the app would ask the real \
                Sandbox store. A simulator fault, not an app fault.
                """)
        }
    }
}
