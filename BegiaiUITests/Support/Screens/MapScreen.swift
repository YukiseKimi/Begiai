import XCTest

@MainActor
struct MapScreen {
    let journey: JourneyApp

    func expectEveryCountedTrainOnTheMap(file: StaticString = #filePath, line: UInt = #line) {
        let header = journey.wait(
            for: journey.element(A11yID.Map.runningCount), "the running count", on: "Map",
            timeout: 15, file: file, line: line)
        let count = Int(header.value as? String ?? "") ?? 0
        XCTAssertGreaterThan(count, 0, "Map: no train runs at the sealed time", file: file, line: line)
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train)
        XCTAssertEqual(
            trains.count, count, "Map: the header counts \(count) trains, the map shows \(trains.count)",
            file: file, line: line)
    }

    func starTopLine(file: StaticString = #filePath, line: UInt = #line) -> String {
        let name = journey.wait(for: journey.element(A11yID.Map.lineName), "the top line", on: "Map", file: file, line: line).label
        journey.wait(for: journey.element(A11yID.Map.lineStar), "the top line's star", on: "Map", file: file, line: line).tap()
        return name
    }

    func showStarred(file: StaticString = #filePath, line: UInt = #line) {
        let filter = journey.wait(for: journey.element(A11yID.Map.filter), "the line filter", on: "Map", file: file, line: line)
        journey.wait(for: filter.buttons["Starred"], "the Starred segment", on: "Map", file: file, line: line).tap()
    }

    func expectOnlyLine(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let names = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.lineName)
        journey.wait(for: names.firstMatch, "a starred line", on: "Map (Starred)", file: file, line: line)
        XCTAssertEqual(
            names.allElementsBoundByIndex.map(\.label), [name], "Map (Starred): the list is not just \(name)", file: file, line: line)
    }
}
