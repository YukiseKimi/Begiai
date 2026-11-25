import XCTest

/// The App Store shots, not a journey: it runs only when `TEST_RUNNER_BEGIAI_SHOTS` names
/// a folder, so the journey lane skips it. `Store/Screenshots/take.sh` runs it and sets the
/// simulator's appearance; `Store/Screenshots/shots.json` says what each shot shows.
/// `script/readme-gif.sh` runs `test07MapTimelapse`, the README's GIF.
final class StoreShotsJourney: JourneyCase {
    private var folder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let path = ProcessInfo.processInfo.environment["BEGIAI_SHOTS"] ?? ""
        try XCTSkipIf(path.isEmpty, "Store shots: run them with Store/Screenshots/take.sh or script/readme-gif.sh")
        folder = URL(filePath: path, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// 1. "See every train in Lithuania move": the map around Vilnius, the panel at half height.
    @MainActor
    func test01Map() {
        let journey = launchOnTheMap()
        zoomToVilnius(journey)
        MapScreen(journey: journey).expectPanel("Half")
        save("01-map", journey)
    }

    /// 2. "Follow your train stop by stop": a Vilnius – Kaunas train's page.
    @MainActor
    func test02Train() {
        let journey = launchOnTheMap()
        zoomToVilnius(journey)
        // A train to Kaunas if one has a spot no other marker covers, else a train to Vilnius.
        let pick =
            tapSpot(of: { $0.label.hasPrefix("Train to Kaunas") }, journey)
            ?? tapSpot(of: { $0.label.hasPrefix("Train to Vilnius") }, journey)
        guard let (train, spot) = pick else {
            XCTFail("Store shots: no train to Kaunas or Vilnius to tap above the panel")
            return
        }
        let destination = train.label.hasPrefix("Train to Kaunas") ? "Kaunas" : "Vilnius"
        journey.app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: spot.x, dy: spot.y)).tap()
        TrainScreen(journey: journey).expectTrain(to: destination)
        save("02-train", journey)
    }

    /// 3. "Read a line at a glance": the Line Diagram of Vilnius – Kaunas.
    @MainActor
    func test03LineDiagram() {
        let journey = launchOnTheMap()
        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        diagram.expectLine("Vilnius – Kaunas")
        diagram.expectALineWithItsTrains()
        save("03-line-diagram", journey)
    }

    /// 4. "Know when your next train leaves": the Vilnius board in the map's panel. Trains
    /// cover Vilnius on the map, so the drive stars it from the Line Diagram and opens it
    /// from "Your stations" above the lines.
    @MainActor
    func test04Board() {
        let journey = launchOnTheMap()
        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        diagram.expectLine("Vilnius – Kaunas")
        XCTAssertEqual(diagram.openAStation(), "Vilnius", "Line Diagram: the first station is not Vilnius")
        let board = BoardScreen(journey: journey)
        board.star()
        board.back()
        journey.wait(for: journey.element(A11yID.Tabs.map), "the Map tab", on: "Tabs").tap()
        let map = MapScreen(journey: journey)
        map.expectLines()
        zoomToVilnius(journey)
        map.openStarredStation("Vilnius")
        board.expectBoard(of: "Vilnius")
        // The sealed time, 15:55 UTC, is 17:55 in Vilnius.
        board.expectMinutesWithinTheHour(now: (17, 55), busy: true)
        save("04-board", journey)
    }

    /// 5. "Easy on the eyes at night": slide 1's map, with the simulator in dark mode.
    @MainActor
    func test05MapDark() {
        let journey = launchOnTheMap()
        zoomToVilnius(journey)
        save("05-map-dark", journey)
    }

    /// 6. "Made for every rider": About, with Larger markers and High contrast in view.
    @MainActor
    func test06About() {
        let journey = launchOnTheMap()
        let about = AboutScreen(journey: journey)
        about.open()
        let contrast = journey.element(A11yID.About.highContrast)
        journey.wait(for: contrast, "the High contrast switch", on: "About")
        // Scroll until the Display section sits at the bottom, above the tips.
        let target = journey.app.frame.height * 0.95
        let origin = journey.app.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<5 {
            let shift = contrast.frame.maxY - target
            if abs(shift) < 8 { break }
            let x = journey.app.frame.width * 0.5
            let start = origin.withOffset(CGVector(dx: x, dy: 420))
            start.press(
                forDuration: 0.2, thenDragTo: origin.withOffset(CGVector(dx: x, dy: 420 - shift)),
                withVelocity: 120, thenHoldForDuration: 0.6)
        }
        XCTAssertTrue(contrast.isHittable && journey.element(A11yID.About.largerMarkers).isHittable, "About: Display is not in view")
        save("06-about", journey)
    }

    /// The README's GIF, not a slide: the map around Vilnius from 07:20 with the clock 60 times
    /// faster. `script/readme-gif.sh` sets dark mode, waits for the `ready` file and records
    /// the screen while the drive holds the app open.
    @MainActor
    func test07MapTimelapse() {
        let journey = JourneyApp()
        journey.launch(.map, at: "2026-11-17T05:20:00Z", speed: 60)
        MapScreen(journey: journey).expectPanel("Half")
        zoomToVilnius(journey)
        // Let the map tiles of the new zoom load before the recording starts.
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "tiles")], timeout: 4)
        XCTAssertNoThrow(try Data().write(to: folder.appending(path: "ready")))
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "recording")], timeout: 20)
    }

    @MainActor
    private func launchOnTheMap() -> JourneyApp {
        let journey = JourneyApp()
        journey.launch(.map)
        MapScreen(journey: journey).expectEveryCountedTrainOnTheMap()
        return journey
    }

    /// The first wanted train above the panel with a spot that no other train or station
    /// covers, and that spot, so a tap there opens that train.
    @MainActor
    private func tapSpot(of wanted: (XCUIElement) -> Bool, _ journey: JourneyApp) -> (XCUIElement, CGPoint)? {
        let all = trains(journey)
        let stations = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station)
            .allElementsBoundByIndex.map(\.frame)
        for (index, train) in all.enumerated() where wanted(train) && train.isHittable {
            let frame = train.frame
            guard frame.minY > 70, frame.maxY < journey.app.frame.height * 0.45 else { continue }
            let others =
                all.enumerated().filter { $0.offset != index }.map { $0.element.frame.insetBy(dx: -3, dy: -3) }
                + stations.map { $0.insetBy(dx: -3, dy: -3) }
            let inner = frame.insetBy(dx: 6, dy: 6)
            for y in stride(from: inner.minY, through: inner.maxY, by: 2) {
                for x in stride(from: inner.minX, through: inner.maxX, by: 2) {
                    let point = CGPoint(x: x, y: y)
                    if others.allSatisfy({ !$0.contains(point) }) { return (train, point) }
                }
            }
        }
        return nil
    }

    @MainActor
    private func trains(_ journey: JourneyApp) -> [XCUIElement] {
        journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.train).allElementsBoundByIndex
    }

    /// Zooms in on Vilnius with double taps beside it, then drags it to the top middle of the
    /// map, above the half-height panel. Each step reads the markers again, so a tap or a drag
    /// never lands on a train or a station.
    @MainActor
    private func zoomToVilnius(_ journey: JourneyApp, taps: Int = 2) {
        let origin = journey.app.coordinate(withNormalizedOffset: .zero)
        for _ in 0..<taps {
            let point = freePoint(near: vilniusCenter(journey), journey)
            origin.withOffset(CGVector(dx: point.x, dy: point.y)).doubleTap()
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "zoom")], timeout: 2)
        }
        let target = CGPoint(x: journey.app.frame.width * 0.5, y: journey.app.frame.height * 0.27)
        for _ in 0..<4 {
            let from = vilniusCenter(journey)
            let shift = CGVector(dx: target.x - from.x, dy: target.y - from.y)
            if hypot(shift.dx, shift.dy) < 10 { break }
            // Start where the drag ends on the map too, away from every marker.
            let start = freePoint(
                near: CGPoint(x: journey.app.frame.width * 0.5 - shift.dx / 2, y: 220 - shift.dy / 2), journey)
            origin.withOffset(CGVector(dx: start.x, dy: start.y)).press(
                forDuration: 0.2, thenDragTo: origin.withOffset(CGVector(dx: start.x + shift.dx, dy: start.y + shift.dy)),
                withVelocity: 150, thenHoldForDuration: 0.6)
            _ = XCTWaiter.wait(for: [XCTestExpectation(description: "pan")], timeout: 1.5)
        }
    }

    @MainActor
    private func vilniusCenter(_ journey: JourneyApp) -> CGPoint {
        let vilnius = journey.app.descendants(matching: .any).matching(identifier: A11yID.Map.station)
            .matching(NSPredicate(format: "label == 'Vilnius'")).firstMatch
        journey.wait(for: vilnius, "Vilnius on the map", on: "Store shots")
        return CGPoint(x: vilnius.frame.midX, y: vilnius.frame.midY)
    }

    /// The point nearest `near`, on the map above the panel and left of the buttons, at least
    /// 14 points from every train and station.
    @MainActor
    private func freePoint(near: CGPoint, _ journey: JourneyApp) -> CGPoint {
        let markers = markerFrames(journey).map { $0.insetBy(dx: -14, dy: -14) }
        let width = journey.app.frame.width
        var best = CGPoint(x: 30, y: 400)
        var bestDistance = CGFloat.infinity
        for y in stride(from: 80.0, through: 430.0, by: 6.0) {
            for x in stride(from: 20.0, through: width - 80, by: 6.0) {
                let point = CGPoint(x: x, y: y)
                guard markers.allSatisfy({ !$0.contains(point) }) else { continue }
                let d = hypot(x - near.x, y - near.y)
                if d < bestDistance {
                    best = point
                    bestDistance = d
                }
            }
        }
        return best
    }

    /// The frames of every train and station, read in one snapshot, so that a train that
    /// starts or ends meanwhile (the fast clock of the GIF) cannot break the read.
    @MainActor
    private func markerFrames(_ journey: JourneyApp) -> [CGRect] {
        let root: any XCUIElementSnapshot
        do {
            root = try journey.app.snapshot()
        } catch {
            XCTFail("Store shots: no snapshot of the map: \(error)")
            return []
        }
        var frames: [CGRect] = []
        var stack: [any XCUIElementSnapshot] = [root]
        while let element = stack.popLast() {
            if element.identifier == A11yID.Map.train || element.identifier == A11yID.Map.station {
                frames.append(element.frame)
            }
            stack.append(contentsOf: element.children)
        }
        return frames
    }

    @MainActor
    private func save(_ name: String, _ journey: JourneyApp) {
        // Let the panel and the map settle before the shot.
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 2)
        let shot = XCUIScreen.main.screenshot()
        let file = folder.appending(path: "\(name).png")
        XCTAssertNoThrow(try shot.pngRepresentation.write(to: file))
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
