import XCTest

@MainActor
struct AboutScreen {
    let journey: JourneyApp

    func open(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.About.open), "the ⓘ button", on: "Map", file: file, line: line).tap()
        journey.wait(for: journey.element(A11yID.About.close), "the close button", on: "About", file: file, line: line)
    }

    func expectItsSourcesAndDate(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.About.source), "the timetable source", on: "About", file: file, line: line)
        let date = journey.wait(for: journey.element(A11yID.About.timetableDate), "the timetable date", on: "About", file: file, line: line)
        XCTAssertTrue(date.label.contains("2026"), "About: the date reads \(date.label)", file: file, line: line)
        let unofficial = journey.element(A11yID.About.unofficial)
        for _ in 0..<4 where !unofficial.exists { journey.app.swipeUp() }
        journey.wait(for: unofficial, "the unofficial note", on: "About", file: file, line: line)
    }

    /// Buys the smallest tip in the local StoreKit file, and waits for the thank-you.
    func tipACoffee(file: StaticString = #filePath, line: UInt = #line) {
        let buy = journey.app.buttons.matching(NSPredicate(format: "label CONTAINS '0.99'")).firstMatch
        for _ in 0..<4 where !buy.isHittable { journey.app.swipeUp() }
        journey.wait(for: buy, "the Coffee tip", on: "About", timeout: 15, file: file, line: line).tap()
        journey.wait(for: journey.element(A11yID.About.tipThanks), "the thank-you", on: "About", timeout: 15, file: file, line: line)
    }

    func close(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.About.close), "the close button", on: "About", file: file, line: line).tap()
        XCTAssertTrue(journey.element(A11yID.About.close).waitForNonExistence(timeout: 5), "About: it stays open", file: file, line: line)
    }
}
