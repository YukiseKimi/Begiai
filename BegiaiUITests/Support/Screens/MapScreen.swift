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
        guard let train = movingTrainsAboveThePanel(file: file, line: line).first else {
            XCTFail("Map: no train shows above the panel", file: file, line: line)
            return ""
        }
        return open(train, file: file, line: line)
    }

    /// Taps the first train above the panel, or the first to `destination`, for the shots. A
    /// station's name is the same in each language, so this works in any language. Few trains
    /// to one station are clear of every station marker, so one to `destination` need not be.
    func tapFirstTrain(to destination: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let train: XCUIElement?
        if let destination {
            journey.wait(for: journey.element(A11yID.Map.train), "a train", on: "Map", file: file, line: line)
            let sight = mapInSight
            train = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
                .first {
                    // “Train to Kaunas, scheduled”, “Traukinys į stotį Kaunas, pagal tvarkaraštį”.
                    $0.label.contains("\(destination),") && $0.isHittable && sight.contains(centre(of: $0.frame))
                        && ($0.value as? String) != Self.standing
                }
        } else {
            train = movingTrainsAboveThePanel(file: file, line: line).first
        }
        guard let train else {
            XCTFail("Map: no train to \(destination ?? "anywhere") shows above the panel", file: file, line: line)
            return
        }
        train.tap()
    }

    /// Opens the first train whose page has another route than `route` (“Vilnius → Kaunas”),
    /// and returns its route. Each train with that route opens and closes again.
    func openFirstTrain(otherThan route: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        let page = TrainScreen(journey: journey)
        for train in movingTrainsAboveThePanel(file: file, line: line) {
            _ = open(train, file: file, line: line)
            let opened = page.route(file: file, line: line)
            if opened != route { return opened }
            page.back(file: file, line: line)
            expectLines(file: file, line: line)
        }
        XCTFail("Map: no train above the panel goes other than \(route)", file: file, line: line)
        return ""
    }

    /// The trains above the panel that a tap opens: moving, so the tap opens the train and
    /// not its station, and clear of every station marker.
    private func movingTrainsAboveThePanel(file: StaticString, line: UInt) -> LazyFilterSequence<[XCUIElement]> {
        journey.wait(for: journey.element(A11yID.Map.train), "a train", on: "Map", file: file, line: line)
        let sight = mapInSight
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station).allElementsBoundByIndex
            .map(\.frame)
        let clear = { (train: XCUIElement) in stations.allSatisfy { !$0.intersects(train.frame) } }
        // A tap on the centre of a standing train opens its station, so pick a moving train.
        let moving = { (train: XCUIElement) in (train.value as? String) != Self.standing }
        return trains.lazy.filter { $0.isHittable && sight.contains(centre(of: $0.frame)) && clear($0) && moving($0) }
    }

    /// Taps a train and returns its destination, from its VoiceOver label.
    private func open(_ train: XCUIElement, file: StaticString, line: UInt) -> String {
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
        let sight = mapInSight
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station).allElementsBoundByIndex
            .map(\.frame)
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
            .filter { ($0.value as? String) == Self.standing }
            .map(\.frame).filter { train in
                sight.contains(centre(of: train)) && stations.contains { $0.contains(CGPoint(x: train.midX, y: train.midY)) }
            }
        let page = TrainScreen(journey: journey)
        for train in trains {
            // On the train beyond its station ring: past the ring radius (8 points at city zoom, 6 at
            // country zoom), inside the train.
            journey.spot(CGPoint(x: train.midX, y: train.midY + train.height * 0.38)).tap()
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

    /// Types into the station search above the line filter, expects the stations found to be
    /// just `expected`, in that order, and opens the first one.
    func searchStation(_ query: String, expect expected: [String], file: StaticString = #filePath, line: UInt = #line) {
        let field = journey.wait(for: journey.element(A11yID.Map.search), "the station search", on: "Map", file: file, line: line)
        field.tap()
        field.typeText(query)
        let results = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.searchResult)
        journey.wait(for: results.firstMatch, "a station found for \(query)", on: "Map (search)", file: file, line: line)
        XCTAssertEqual(
            results.allElementsBoundByIndex.map(\.label), expected, "Map (search): \(query) finds the wrong stations",
            file: file, line: line)
        results.firstMatch.tap()
    }

    /// The glass column that holds the panel beside the map on a wide screen, such as the open
    /// iPhone Duo. An iPhone has none: its panel is a sheet over the bottom of the map.
    var column: XCUIElement { journey.element(A11yID.Map.column) }

    /// True on a wide screen, where the panel is a column with no heights to drag or step.
    func hasColumn(file: StaticString = #filePath, line: UInt = #line) -> Bool {
        expectLines(file: file, line: line)
        return column.exists
    }

    /// Once the map follows a train to `destination`, such a train stands near the middle of
    /// the map in sight, not under the column.
    func expectTrainFollowed(to destination: String, file: StaticString = #filePath, line: UInt = #line) {
        let sight = mapInSight
        let middle = CGPoint(x: sight.midX, y: sight.midY)
        let trains = journey.app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", A11yID.Map.train))
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Train to \(destination),"))
        // At city zoom a train's frame takes in its label, which hangs to the right of the
        // marker; the marker is the square at the frame's left.
        let marker = { (frame: CGRect) in CGPoint(x: frame.minX + frame.height / 2, y: frame.midY) }
        let centred = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                trains.allElementsBoundByIndex.contains { hypot(marker($0.frame).x - middle.x, marker($0.frame).y - middle.y) < 40 }
            }, object: nil)
        XCTAssertEqual(
            XCTWaiter.wait(for: [centred], timeout: 10), .completed,
            "Map: no train to \(destination) stands near \(middle), the middle of the map beside the column: "
                + trains.allElementsBoundByIndex.map { "\($0.frame)" }.joined(separator: ", "), file: file, line: line)
    }

    /// The map where the panel does not cover it: above a half-height sheet, or before the column.
    private var mapInSight: CGRect {
        let size = journey.window.frame.size
        guard column.exists else { return CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.45) }
        return CGRect(x: 0, y: 0, width: column.frame.minX, height: size.height)
    }

    /// The map where the panel does not cover it, `margin` points from the panel's edge.
    private func clearOfThePanel(by margin: CGFloat, file: StaticString, line: UInt) -> CGRect {
        let size = journey.window.frame.size
        if column.exists { return CGRect(x: 0, y: 0, width: column.frame.minX - margin, height: size.height) }
        let panel = journey.wait(for: journey.element(A11yID.Map.panel), "the panel's handle", on: "Map", file: file, line: line)
        return CGRect(x: 0, y: 0, width: size.width, height: panel.frame.minY - margin)
    }

    private func centre(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    /// The panel's handle says how tall the panel is: Small, Half or Full. A column has no
    /// heights: it stays beside the map at the screen's full height.
    func expectPanel(_ height: String, file: StaticString = #filePath, line: UInt = #line) {
        if column.exists {
            XCTAssertTrue(column.isHittable, "Map: the column does not show", file: file, line: line)
            return
        }
        let handle = journey.wait(for: journey.element(A11yID.Map.panel), "the panel's handle", on: "Map", file: file, line: line)
        let said = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", height), object: handle)
        XCTAssertEqual(
            XCTWaiter.wait(for: [said], timeout: 3), .completed,
            "Map: the panel's handle says \(handle.value ?? "nothing"), not \(height)", file: file, line: line)
    }

    func tapPanelHandle(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Map.panel), "the panel's handle", on: "Map", file: file, line: line).tap()
    }

    /// Holds the panel's handle and drags it slowly to `height` of the screen from the top, the
    /// way a finger moves it, so that the panel follows the finger the whole way.
    func dragPanelHandle(toHeight height: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        let handle = journey.wait(for: journey.element(A11yID.Map.panel), "the panel's handle", on: "Map", file: file, line: line)
        let target = journey.app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: height))
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// Taps the map above the panel where no train or station is, as a rider taps outside the panel.
    func tapOutsideThePanel(file: StaticString = #filePath, line: UInt = #line) {
        emptySpot(file: file, line: line)?.tap()
    }

    /// Double-taps the map above the panel where no train or station is, as a rider zooms in.
    func doubleTapOutsideThePanel(file: StaticString = #filePath, line: UInt = #line) {
        emptySpot(file: file, line: line)?.doubleTap()
    }

    /// Taps the map above the panel with a finger that slides 5 points, as on a moving train.
    func shakyTapOutsideThePanel(file: StaticString = #filePath, line: UInt = #line) {
        guard let spot = emptySpot(file: file, line: line) else { return }
        spot.press(forDuration: 0.05, thenDragTo: spot.withOffset(CGVector(dx: 3, dy: 4)))
    }

    /// Drags the map from a spot above the panel where no train or station is, as a rider moves the map.
    func dragOutsideThePanel(file: StaticString = #filePath, line: UInt = #line) {
        guard let spot = emptySpot(file: file, line: line) else { return }
        spot.press(forDuration: 0.05, thenDragTo: spot.withOffset(CGVector(dx: 20, dy: 15)))
    }

    /// A spot of the map above the panel, clear of the trains, the stations, the status bar, the
    /// buttons at the top right and the panel's top edge.
    private func emptySpot(file: StaticString, line: UInt) -> XCUICoordinate? {
        let sight = clearOfThePanel(by: 40, file: file, line: line)
        // Beside a column the buttons at the top right stand where the spots are.
        let markers =
            (journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
            + journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station).allElementsBoundByIndex
            + [journey.element(A11yID.Map.locate), journey.element(A11yID.About.open)])
            .map { $0.frame.insetBy(dx: -30, dy: -30) }
        let size = journey.window.frame.size
        let spots = stride(from: 0.15, through: 0.6, by: 0.05).flatMap { x in
            stride(from: 0.15, to: 0.45, by: 0.03).map { y in CGPoint(x: size.width * x, y: size.height * y) }
        }
        guard let spot = spots.first(where: { spot in sight.contains(spot) && markers.allSatisfy { !$0.contains(spot) } })
        else {
            XCTFail("Map: no empty spot of the map shows above the panel", file: file, line: line)
            return nil
        }
        return journey.spot(spot)
    }

    func expectNoPage(file: StaticString = #filePath, line: UInt = #line) {
        expectLines(file: file, line: line)
        XCTAssertFalse(journey.element(A11yID.Train.title).exists, "Map: the train page is still open", file: file, line: line)
        XCTAssertFalse(journey.element(A11yID.Board.title).exists, "Map: the station board is still open", file: file, line: line)
    }

    func expectLines(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Map.runningCount), "the running count", on: "Map", file: file, line: line)
    }

    func openStationAboveThePanel(file: StaticString = #filePath, line: UInt = #line) -> String {
        journey.wait(for: journey.element(A11yID.Map.station), "a station", on: "Map", file: file, line: line)
        let sight = mapInSight
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station).allElementsBoundByIndex
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex.map(\.frame)
        let clear = { (station: XCUIElement) in trains.allSatisfy { !$0.intersects(station.frame) } }
        guard let station = stations.first(where: { $0.isHittable && sight.contains(centre(of: $0.frame)) && clear($0) }) else {
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
        let sight = mapInSight
        let trains = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
            .map { (frame: $0.frame, standing: ($0.value as? String) == Self.standing) }
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station).allElementsBoundByIndex
        // A ring that only standing trains cover, each centred on it, so whichever one takes
        // the tap, the tap is on its station ring.
        guard
            let station = stations.first(where: { station in
                let centre = CGPoint(x: station.frame.midX, y: station.frame.midY)
                let over = trains.filter { $0.frame.contains(centre) }
                return sight.contains(centre) && !over.isEmpty
                    && over.allSatisfy { train in
                        train.standing && hypot(train.frame.midX - centre.x, train.frame.midY - centre.y) < 4
                    }
            })
        else { return nil }
        let name = station.label
        journey.spot(CGPoint(x: station.frame.midX, y: station.frame.midY)).tap()
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

    /// The trains on the screen above the panel, or before the column. Fewer show once the map zooms in.
    func trainsInSight(file: StaticString = #filePath, line: UInt = #line) -> Int {
        journey.wait(for: journey.element(A11yID.Map.train), "a train", on: "Map", timeout: 15, file: file, line: line)
        let sight = clearOfThePanel(by: 0, file: file, line: line)
        return journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
            .filter { sight.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY)) }.count
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
