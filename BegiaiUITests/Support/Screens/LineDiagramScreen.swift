import XCTest

@MainActor
struct LineDiagramScreen {
    let journey: JourneyApp

    func open(file: StaticString = #filePath, line: UInt = #line) {
        let tab = journey.wait(
            for: journey.tab(.lineDiagram), "the Line Diagram tab", on: "Tabs", file: file, line: line)
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

    /// Swipes the diagram sideways between its first two stations, where no button is, and
    /// gives the name of the line it shows after.
    @discardableResult
    func swipeToAnotherLine(left: Bool, file: StaticString = #filePath, line: UInt = #line) -> String {
        let title = journey.element(A11yID.LineDiagram.page)
        let before = title.label
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.LineDiagram.station)
        journey.wait(for: stations.firstMatch, "a station", on: "Line Diagram", file: file, line: line)
        let y = (stations.element(boundBy: 0).frame.midY + stations.element(boundBy: 1).frame.midY) / 2
        // From a quarter into the window to three quarters, clear of the edges the system keeps.
        let window = journey.window.frame
        let near = journey.spot(CGPoint(x: window.width * (left ? 0.75 : 0.25), y: y))
        let far = journey.spot(CGPoint(x: window.width * (left ? 0.25 : 0.75), y: y))
        near.press(forDuration: 0.01, thenDragTo: far, withVelocity: .fast, thenHoldForDuration: 0)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", before), object: title)
        XCTAssertEqual(
            XCTWaiter.wait(for: [changed], timeout: 5), .completed,
            "Line Diagram: a swipe to the \(left ? "left" : "right") left the line at \(before)", file: file, line: line)
        return title.label
    }

    func expectLine(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lineName, name, "Line Diagram: it opened on \(lineName), not on \(name)", file: file, line: line)
    }

    /// Taps the first train, and gives the name of its last station.
    @discardableResult
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

    /// Taps the diagram left of `limit` where no train, station, chip or text is, as a rider
    /// taps outside the column on a wide screen.
    func tapTheDiagramBeside(_ limit: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        let window = journey.window.frame
        let ids = [
            A11yID.LineDiagram.train, A11yID.LineDiagram.station, A11yID.LineDiagram.chip, A11yID.LineDiagram.page,
            A11yID.LineDiagram.frequency, A11yID.Notices.link, A11yID.Timetable.stale,
        ]
        let taken = ids.flatMap { id in
            journey.app.descendants(matching: .any).matching(identifier: id).allElementsBoundByIndex.map {
                $0.frame.insetBy(dx: -20, dy: -20)
            }
        }
        let spots = stride(from: 0.1, through: 0.9, by: 0.1).flatMap { x in
            stride(from: 0.4, through: 0.9, by: 0.05).map { y in CGPoint(x: limit * x, y: window.height * y) }
        }
        guard let spot = spots.first(where: { spot in taken.allSatisfy { !$0.contains(spot) } }) else {
            XCTFail("Line Diagram: no empty spot of the diagram beside the column", file: file, line: line)
            return
        }
        journey.spot(spot).tap()
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
