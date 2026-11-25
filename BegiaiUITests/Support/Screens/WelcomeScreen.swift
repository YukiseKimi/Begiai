import XCTest

@MainActor
struct WelcomeScreen {
    let journey: JourneyApp

    /// Reads each card and taps Next, then Start on the last one, until the sheet closes;
    /// gives the titles in order. Stops after `limit` cards, so a sheet that never closes fails.
    @discardableResult
    func readEachCardAndStart(limit: Int = 10, file: StaticString = #filePath, line: UInt = #line) -> [String] {
        let title = journey.element(A11yID.Welcome.title)
        let next = journey.element(A11yID.Welcome.next)
        var titles: [String] = []
        while titles.count < limit {
            journey.wait(for: title, "a card title", on: "Welcome", file: file, line: line)
            let shown = title.label
            titles.append(shown)
            journey.wait(for: next, "the Next button", on: "Welcome", file: file, line: line).tap()
            // Either the next card shows, or Start closed the sheet.
            let moved = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in !next.exists || title.label != shown }, object: nil)
            XCTAssertEqual(
                XCTWaiter.wait(for: [moved], timeout: 5), .completed, "Welcome: Next did not move on from \(shown)",
                file: file, line: line)
            if !next.exists { return titles }
        }
        XCTFail("Welcome: the sheet stays after \(limit) cards", file: file, line: line)
        return titles
    }

    func expectNoWelcome(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(
            journey.element(A11yID.Welcome.title).waitForExistence(timeout: 3), "Welcome: the sheet shows again", file: file, line: line)
    }
}
