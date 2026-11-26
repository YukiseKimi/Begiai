import XCTest

final class FreshDataJourney: JourneyCase {
    @MainActor
    func testAnOldTimetableSaysItsDate() {
        let journey = JourneyApp()
        // The shipped timetable is from 17 Nov 2026; ten days later it is old.
        journey.launch(.map, at: "2026-11-27T10:00:00Z")

        MapScreen(journey: journey).expectStaleNote(day: 17, month: "Nov")
    }

    @MainActor
    func testAFreshTimetableSaysNothing() {
        let journey = JourneyApp()
        journey.launch(.map)

        MapScreen(journey: journey).expectNoStaleNote()
    }

    @MainActor
    func testEachLineLinksToTheNotices() {
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        diagram.expectNoticesLink()
        diagram.openATrain()
        diagram.expectNoticesLinkOnTheTrainPage()
    }
}
