import XCTest

@MainActor
struct WelcomeScreen {
    let journey: JourneyApp

    /// Reads each card and taps Next, then Start on the last one; gives the titles in order.
    @discardableResult
    func readEachCardAndStart(file: StaticString = #filePath, line: UInt = #line) -> [String] {
        var titles: [String] = []
        for _ in 0..<3 {
            let title = journey.wait(for: journey.element(A11yID.Welcome.title), "a card title", on: "Welcome", file: file, line: line)
            titles.append(title.label)
            journey.wait(for: journey.element(A11yID.Welcome.next), "the Next button", on: "Welcome", file: file, line: line).tap()
            _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label != %@", titles.last ?? ""), object: journey.element(A11yID.Welcome.title))], timeout: 2)
        }
        XCTAssertTrue(
            journey.element(A11yID.Welcome.next).waitForNonExistence(timeout: 5),
            "Welcome: the sheet stays after Start", file: file, line: line)
        return titles
    }

    func expectNoWelcome(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(
            journey.element(A11yID.Welcome.title).waitForExistence(timeout: 3), "Welcome: the sheet shows again", file: file, line: line)
    }
}
