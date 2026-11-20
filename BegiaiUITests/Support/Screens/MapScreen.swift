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
        // The header can show before the map has drawn its markers.
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train)
        let drawn = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in trains.count == count }, object: nil)
        _ = XCTWaiter.wait(for: [drawn], timeout: 10)
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

    func openFirstTrain(file: StaticString = #filePath, line: UInt = #line) -> String {
        journey.wait(for: journey.element(A11yID.Map.train), "a train", on: "Map", file: file, line: line)
        let aboveThePanel = journey.app.frame.height * 0.45
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station).allElementsBoundByIndex
            .map(\.frame)
        let clear = { (train: XCUIElement) in stations.allSatisfy { !$0.intersects(train.frame) } }
        // A tap on the centre of a standing train opens its station, so pick a moving train.
        let moving = { (train: XCUIElement) in (train.value as? String) != Self.standing }
        guard let train = trains.first(where: { $0.isHittable && $0.frame.midY < aboveThePanel && clear($0) && moving($0) }) else {
            XCTFail("Map: no train shows above the panel", file: file, line: line)
            return ""
        }
        let label = train.label
        train.tap()
        guard let range = label.range(of: "Train to "), let end = label.range(of: ", scheduled") else {
            XCTFail("Map: a train reads \(label)", file: file, line: line)
            return ""
        }
        return String(label[range.upperBound..<end.lowerBound])
    }

    /// The VoiceOver value of a train that stands at a station.
    static let standing = "Standing at a station"

    /// Opens a train that stands at a big station at country zoom. A tap on its centre opens the
    /// station, so the tap goes on the train beyond its station ring. Tries each such train.
    /// Returns the station's name, or nil when no train stands at a station.
    func openTrainStandingAtAStation(file: StaticString = #filePath, line: UInt = #line) -> String? {
        journey.wait(for: journey.element(A11yID.Map.train), "a train", on: "Map", file: file, line: line)
        let aboveThePanel = journey.app.frame.height * 0.45
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station).allElementsBoundByIndex
            .map(\.frame)
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
            .filter { ($0.value as? String) == Self.standing }
            .map(\.frame).filter { train in
                train.midY < aboveThePanel && stations.contains { $0.contains(CGPoint(x: train.midX, y: train.midY)) }
            }
        let page = TrainScreen(journey: journey)
        for train in trains {
            // On the train beyond its station ring: past the 8-point ring radius, inside the train.
            let spot = CGVector(dx: train.midX, dy: train.midY + train.height * 0.38)
            journey.app.coordinate(withNormalizedOffset: .zero).withOffset(spot).tap()
            let now = journey.element(A11yID.Train.now)
            guard now.waitForExistence(timeout: 3) else { continue }
            if now.label.hasPrefix("At ") { return page.place(file: file, line: line) }
            page.back(file: file, line: line)
        }
        return nil
    }

    /// The button over a chosen train names its station, and a tap opens the station's board.
    func openStationChip(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let chip = journey.wait(
            for: journey.element(A11yID.Map.stationChip), "the station button over the train", on: "Map", file: file, line: line)
        XCTAssertEqual(chip.label, name, "Map: the station button reads \(chip.label), not \(name)", file: file, line: line)
        chip.tap()
    }

    /// A starred station shows above the lines with its next train, and a tap opens its board.
    func openStarredStation(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = journey.wait(
            for: journey.element(A11yID.Map.starredStation), "the starred station", on: "Map", file: file, line: line)
        XCTAssertTrue(
            row.label.hasPrefix(name) && (row.label.contains("Next: ") || row.label.contains("No trains")),
            "Map: the starred station reads \(row.label)", file: file, line: line)
        row.tap()
    }

    /// The panel's handle says how tall the panel is: Small, Half or Full.
    func expectPanel(_ height: String, file: StaticString = #filePath, line: UInt = #line) {
        let handle = journey.wait(for: journey.element(A11yID.Map.panel), "the panel's handle", on: "Map", file: file, line: line)
        let said = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", height), object: handle)
        XCTAssertEqual(
            XCTWaiter.wait(for: [said], timeout: 3), .completed,
            "Map: the panel's handle says \(handle.value ?? "nothing"), not \(height)", file: file, line: line)
    }

    func tapPanelHandle(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Map.panel), "the panel's handle", on: "Map", file: file, line: line).tap()
    }

    func expectLines(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Map.runningCount), "the running count", on: "Map", file: file, line: line)
    }

    func openStationAboveThePanel(file: StaticString = #filePath, line: UInt = #line) -> String {
        journey.wait(for: journey.element(A11yID.Map.station), "a station", on: "Map", file: file, line: line)
        let aboveThePanel = journey.app.frame.height * 0.45
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station).allElementsBoundByIndex
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex.map(\.frame)
        let clear = { (station: XCUIElement) in trains.allSatisfy { !$0.intersects(station.frame) } }
        guard let station = stations.first(where: { $0.isHittable && $0.frame.midY < aboveThePanel && clear($0) }) else {
            XCTFail("Map: no station shows above the panel", file: file, line: line)
            return ""
        }
        let name = station.label
        station.tap()
        return name
    }

    /// Taps the centre of a station ring that a train covers, and returns the station's name,
    /// or nil when no train covers a station above the panel.
    func openStationUnderATrain(file: StaticString = #filePath, line: UInt = #line) -> String? {
        journey.wait(for: journey.element(A11yID.Map.station), "a station", on: "Map", file: file, line: line)
        let aboveThePanel = journey.app.frame.height * 0.45
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
            .map { (frame: $0.frame, standing: ($0.value as? String) == Self.standing) }
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station).allElementsBoundByIndex
        // A ring that only standing trains cover, each centred on it, so whichever one takes
        // the tap, the tap is on its station ring.
        guard let station = stations.first(where: { station in
            let centre = CGPoint(x: station.frame.midX, y: station.frame.midY)
            let over = trains.filter { $0.frame.contains(centre) }
            return centre.y < aboveThePanel && !over.isEmpty && over.allSatisfy { train in
                train.standing && hypot(train.frame.midX - centre.x, train.frame.midY - centre.y) < 4
            }
        }) else { return nil }
        let name = station.label
        journey.app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: station.frame.midX, dy: station.frame.midY)).tap()
        return name
    }

    func expectFirstTrain(file: StaticString = #filePath, line: UInt = #line) {
        let card = journey.wait(
            for: journey.element(A11yID.Map.firstTrain), "the first train", on: "Map at night",
            file: file, line: line)
        XCTAssertTrue(card.label.contains("→"), "Map at night: the card reads \(card.label)", file: file, line: line)
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train)
        XCTAssertEqual(trains.count, 0, "Map at night: \(trains.count) trains show", file: file, line: line)
    }

    /// The note that the timetable is old, with its day and month: “17 Nov” or “Nov 17”, as the locale writes it.
    func expectStaleNote(day: Int, month: String, file: StaticString = #filePath, line: UInt = #line) {
        let note = journey.wait(for: journey.element(A11yID.Timetable.stale), "the old-timetable note", on: "Map", file: file, line: line)
        let dated = note.label.contains("\(day) \(month)") || note.label.contains("\(month) \(day)")
        XCTAssertTrue(note.label.hasPrefix("Timetable from") && dated, "Map: the note reads \(note.label)", file: file, line: line)
    }

    func expectNoStaleNote(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Map.runningCount), "the running count", on: "Map", file: file, line: line)
        XCTAssertFalse(journey.element(A11yID.Timetable.stale).exists, "Map: a fresh timetable says it is old", file: file, line: line)
    }

    /// The width of a train marker on the map, in points.
    func trainWidth(file: StaticString = #filePath, line: UInt = #line) -> CGFloat {
        journey.wait(for: journey.element(A11yID.Map.train), "a train", on: "Map", timeout: 15, file: file, line: line).frame.width
    }

    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    func expectNoLocationPrompt(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Map.runningCount), "the running count", on: "Map", file: file, line: line)
        XCTAssertFalse(
            springboard.alerts.firstMatch.exists || journey.app.alerts.firstMatch.exists,
            "Map: a prompt shows before any tap", file: file, line: line)
    }

    func tapLocate(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Map.locate), "the Locate button", on: "Map", file: file, line: line).tap()
    }

    func expectLocationPrompt(file: StaticString = #filePath, line: UInt = #line) {
        let shown = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in self.springboard.alerts.firstMatch.exists || self.journey.app.alerts.firstMatch.exists },
            object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [shown], timeout: 10), .completed, "Map: the location prompt never appeared",
            file: file, line: line)
        let alert = springboard.alerts.firstMatch.exists ? springboard.alerts.firstMatch : journey.app.alerts.firstMatch
        XCTAssertGreaterThanOrEqual(alert.buttons.count, 2, "Map: the prompt offers no choice", file: file, line: line)
        alert.buttons.element(boundBy: 1).tap()
    }
}
