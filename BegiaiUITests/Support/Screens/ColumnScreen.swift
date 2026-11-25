import XCTest

/// The glass column that holds a page on a wide screen, such as the open iPhone Duo: beside
/// the map (`A11yID.Map.column`) or over the Line Diagram (`A11yID.LineDiagram.column`).
@MainActor
struct ColumnScreen {
    let journey: JourneyApp
    let identifier: String

    var element: XCUIElement { journey.element(identifier) }

    /// The column stands at the right edge, about as wide as the iPhone's panel and nearly as
    /// tall as the screen, and leaves room on its left. Where the tabs stand in a strip on the
    /// right, as on the open iPhone Duo held wide, the right edge is the strip's left side.
    func expectOnTheRight(file: StaticString = #filePath, line: UInt = #line) {
        let frame = journey.wait(for: element, "the column", on: "Column", file: file, line: line).frame
        let screen = journey.window.frame
        let tab = journey.tab(.map).frame
        let edge = tab.minX > screen.midX ? tab.minX : screen.maxX
        XCTAssertTrue(
            (0...40).contains(edge - frame.maxX),
            "Column: it ends at \(frame.maxX), not just before the right edge at \(edge) (window \(screen), Map tab \(tab))",
            file: file, line: line)
        XCTAssertEqual(frame.width, 360, accuracy: 20, "Column: it is \(frame.width) points wide", file: file, line: line)
        XCTAssertGreaterThan(frame.height, screen.height * 0.6, "Column: it is \(frame.height) points tall", file: file, line: line)
        XCTAssertGreaterThan(frame.minX, 200, "Column: it leaves \(frame.minX) points on its left", file: file, line: line)
    }

    /// The element with `identifier` shows inside the column.
    func expectHolds(_ identifier: String, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        let inside = journey.wait(for: journey.element(identifier), what, on: "Column", file: file, line: line)
        let frame = element.frame
        XCTAssertTrue(
            frame.contains(CGPoint(x: inside.frame.midX, y: inside.frame.midY)),
            "Column: \(what) is at \(inside.frame), outside the column at \(frame)", file: file, line: line)
    }

    func expectGone(file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 3), .completed, "Column: it stays with no page open", file: file, line: line)
    }
}
