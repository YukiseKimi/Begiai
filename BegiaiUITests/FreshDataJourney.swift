import XCTest

final class FreshDataJourney: XCTestCase {
    @MainActor
    func testAnOldTimetableSaysItsDate() {
        continueAfterFailure = false
        let journey = JourneyApp()
        // The shipped timetable is from 17 Nov 2026; ten days later it is old.
        journey.launch(.map, at: "2026-11-27T10:00:00Z")

        MapScreen(journey: journey).expectStaleNote(day: 17, month: "Nov")
        journey.holdLastScreen()
    }

    @MainActor
    func testAFreshTimetableSaysNothing() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        MapScreen(journey: journey).expectNoStaleNote()
        journey.holdLastScreen()
    }

    @MainActor
    func testEachLineLinksToTheNotices() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        diagram.expectNoticesLink()
        _ = diagram.openATrain()
        diagram.expectNoticesLinkOnTheTrainPage()
        journey.holdLastScreen()
    }
}
