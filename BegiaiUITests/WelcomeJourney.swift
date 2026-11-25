import XCTest

final class WelcomeJourney: JourneyCase {
    @MainActor
    func testTheFirstLaunchWelcomesOneTime() {
        let journey = JourneyApp()
        journey.launch(.welcome)

        let welcome = WelcomeScreen(journey: journey)
        let titles = welcome.readEachCardAndStart()
        XCTAssertEqual(titles.count, 3, "Welcome: \(titles.count) cards")
        XCTAssertEqual(Set(titles).count, 3, "Welcome: a card showed twice: \(titles)")
        MapScreen(journey: journey).expectLines()

        journey.relaunch(welcome: true)
        welcome.expectNoWelcome()
    }
}
