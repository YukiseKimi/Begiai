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

    /// Each departure within the hour says its minutes from now, and no later one does.
    /// `now` is the sealed time in Vilnius, as hours and minutes.
    /// With `busy`, at least one train leaves within the hour.
    func expectMinutesWithinTheHour(
        now: (hour: Int, minute: Int), busy: Bool = false, file: StaticString = #filePath, line: UInt = #line
    ) {
        let rows = journey.app.descendants(matching: .any).matching(identifier: A11yID.Board.row)
        journey.wait(for: rows.firstMatch, "a departure", on: "Board", file: file, line: line)
        let clock = /(\d{1,2}):(\d{2})/
        let start = now.hour * 60 + now.minute
        var counted = 0
        for row in rows.allElementsBoundByIndex {
            guard let match = row.label.firstMatch(of: clock), let hour = Int(match.1), let minute = Int(match.2) else {
                XCTFail("Board: a departure reads \(row.label)", file: file, line: line)
                continue
            }
            let away = (hour * 60 + minute - start + 24 * 60) % (24 * 60)
            let expected = away == 0 ? "now" : "in \(away) min"
            if away <= 60 {
                counted += 1
                XCTAssertTrue(row.label.contains(expected), "Board: \(row.label) does not say \(expected)", file: file, line: line)
            } else {
                XCTAssertFalse(row.label.contains(" min"), "Board: \(row.label) counts minutes past the hour", file: file, line: line)
            }
        }
        if busy {
            XCTAssertGreaterThan(counted, 0, "Board: no train leaves within the hour", file: file, line: line)
        }
    }
}
