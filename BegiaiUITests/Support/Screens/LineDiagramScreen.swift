import XCTest

@MainActor
struct LineDiagramScreen {
    let journey: JourneyApp

    func open(file: StaticString = #filePath, line: UInt = #line) {
        let tab = journey.wait(
            for: journey.element(A11yID.Tabs.lineDiagram), "the Line Diagram tab", on: "Tabs", file: file, line: line)
        tab.tap()
        journey.wait(for: journey.element(A11yID.LineDiagram.page), "the name of the line", on: "Line Diagram", file: file, line: line)
    }

    /// The name of the line that the diagram shows.
    var lineName: String { journey.element(A11yID.LineDiagram.page).label }

    func expectALineWithItsTrains(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(
            for: journey.element(A11yID.LineDiagram.frequency), "the frequency of the line", on: "Line Diagram", file: file, line: line)
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.LineDiagram.station)
        XCTAssertGreaterThanOrEqual(stations.count, 2, "Line Diagram: \(stations.count) stations, not 2 or more", file: file, line: line)
        let train = journey.wait(for: journey.element(A11yID.LineDiagram.train), "a train", on: "Line Diagram", file: file, line: line)
        XCTAssertTrue(
            train.label.contains("between") || train.label.contains(", at "),
            "Line Diagram: the train says “\(train.label)”, not where it is", file: file, line: line)
    }

    /// No two trains on the diagram cover each other, so each can be read and tapped.
    func expectTrainsApart(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.LineDiagram.train), "a train", on: "Line Diagram", file: file, line: line)
        let frames = journey.app.descendants(matching: .any).matching(identifier: A11yID.LineDiagram.train)
            .allElementsBoundByIndex.map(\.frame)
        for (index, frame) in frames.enumerated() {
            for other in frames[(index + 1)...] {
                XCTAssertFalse(
                    frame.intersects(other), "Line Diagram: trains at \(frame) and \(other) cover each other",
                    file: file, line: line)
            }
        }
    }

    /// Taps a chip other than the one that shows, and gives the name of its line.
    @discardableResult
    func chooseAnotherLine(file: StaticString = #filePath, line: UInt = #line) -> String {
        let chips = journey.app.descendants(matching: .any).matching(identifier: A11yID.LineDiagram.chip)
        journey.wait(for: chips.firstMatch, "a line chip", on: "Line Diagram", file: file, line: line)
        let current = lineName
        let other = chips.allElementsBoundByIndex.first { $0.label != current && $0.isHittable }
        guard let other else {
            XCTFail("Line Diagram: no other line chip to tap", file: file, line: line)
            return current
        }
        let name = other.label
        other.tap()
        let title = journey.element(A11yID.LineDiagram.page)
        let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", name), object: title)
        XCTAssertEqual(
            XCTWaiter.wait(for: [shown], timeout: 5), .completed, "Line Diagram: the line did not change to \(name)", file: file, line: line
        )
        return name
    }

    func expectLine(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lineName, name, "Line Diagram: it opened on \(lineName), not on \(name)", file: file, line: line)
    }

    /// Taps the first train, and gives the name of its last station.
    func openATrain(file: StaticString = #filePath, line: UInt = #line) -> String {
        let train = journey.wait(for: journey.element(A11yID.LineDiagram.train), "a train", on: "Line Diagram", file: file, line: line)
        let destination = train.label.dropFirst("Train to ".count).prefix { $0 != "," }
        train.tap()
        return String(destination)
    }

    /// Taps the first station, and gives its name.
    func openAStation(file: StaticString = #filePath, line: UInt = #line) -> String {
        let station = journey.wait(
            for: journey.element(A11yID.LineDiagram.station), "a station", on: "Line Diagram", file: file, line: line)
        let name = station.label
        station.tap()
        return name
    }

    func expectNoticesLink(file: StaticString = #filePath, line: UInt = #line) {
        let link = journey.wait(for: journey.element(A11yID.Notices.link), "the notices link", on: "Line Diagram", file: file, line: line)
        XCTAssertEqual(link.elementType, .link, "Line Diagram: the notices link is a \(link.elementType)", file: file, line: line)
        XCTAssertTrue(link.label.contains("LTG Link notices"), "Line Diagram: the link reads \(link.label)", file: file, line: line)
    }

    /// The train page in the sheet has a notices link of its own, besides the diagram's link under the sheet.
    func expectNoticesLinkOnTheTrainPage(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Train.title), "the train page", on: "Line Diagram", file: file, line: line)
        let links = journey.app.descendants(matching: .any).matching(identifier: A11yID.Notices.link)
        // The page opens on the train's stop; the link is above the first stop.
        let stops = journey.app.descendants(matching: .any).matching(identifier: A11yID.Train.stop)
        for _ in 0..<6 where links.count < 2 {
            stops.firstMatch.swipeDown(velocity: .fast)
        }
        XCTAssertGreaterThanOrEqual(links.count, 2, "Line Diagram: the train page has no notices link", file: file, line: line)
    }

    /// A sheet closes with Close, not with a Back button.
    func expectTheSheetCloses(file: StaticString = #filePath, line: UInt = #line) {
        let exit = journey.wait(for: journey.element(A11yID.Train.back), "the Close button", on: "Line Diagram", file: file, line: line)
        XCTAssertEqual(exit.label, "Close", "Line Diagram: the sheet's button reads \(exit.label)", file: file, line: line)
    }

    /// Taps the diagram above the sheet, as a rider taps outside it.
    func tapAboveTheSheet() {
        journey.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
    }

    func expectTheSheetClosed(file: StaticString = #filePath, line: UInt = #line) {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: journey.element(A11yID.Train.title))
        XCTAssertEqual(
            XCTWaiter.wait(for: [gone], timeout: 3), .completed, "Line Diagram: the sheet stays open after a tap outside it",
            file: file, line: line)
    }

    func expectNoFollowButton(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(
            journey.element(A11yID.Train.follow).exists, "Line Diagram: the train page has a Follow button", file: file, line: line)
    }
}
