import XCTest

@MainActor
struct BoardScreen {
    let journey: JourneyApp

    func expectBoard(of station: String, file: StaticString = #filePath, line: UInt = #line) {
        let title = journey.wait(for: journey.element(A11yID.Board.title), "the station's name", on: "Board", file: file, line: line)
        XCTAssertEqual(title.label, station, "Board: the board is for \(title.label), not \(station)", file: file, line: line)
        let rows = journey.app.descendants(matching: .any).matching(identifier: A11yID.Board.row)
        journey.wait(for: rows.firstMatch, "a departure", on: "Board", file: file, line: line)
        XCTAssertTrue((1...8).contains(rows.count), "Board: \(rows.count) departures, not 1 to 8", file: file, line: line)
    }
}
