import XCTest

@MainActor
struct TrainScreen {
    let journey: JourneyApp

    func expectTrain(to destination: String, file: StaticString = #filePath, line: UInt = #line) {
        let title = journey.wait(for: journey.element(A11yID.Train.title), "the train's title", on: "Train", file: file, line: line)
        XCTAssertTrue(
            title.label.hasSuffix("→ \(destination)"), "Train: the title is \(title.label), not a train to \(destination)",
            file: file, line: line)
        let stops = journey.app.descendants(matching: .any).matching(identifier: A11yID.Train.stop)
        journey.wait(for: stops.firstMatch, "the stop list", on: "Train", file: file, line: line)
        XCTAssertGreaterThanOrEqual(stops.count, 2, "Train: the stop list has \(stops.count) stops", file: file, line: line)
    }

    /// The page says where the train is, says that it is scheduled, and marks that stop for VoiceOver.
    func expectWhereTheTrainIs(file: StaticString = #filePath, line: UInt = #line) {
        let now = journey.wait(for: journey.element(A11yID.Train.now), "where the train is", on: "Train", file: file, line: line)
        let standing = now.label.hasPrefix("At ")
        XCTAssertTrue(
            (standing || now.label.hasPrefix("Next: ")) && now.label.contains("in "),
            "Train: where the train is reads \(now.label)", file: file, line: line)
        journey.wait(for: journey.element(A11yID.Train.source), "the Scheduled badge", on: "Train", file: file, line: line)
        let stops = journey.app.descendants(matching: .any).matching(identifier: A11yID.Train.stop)
        let marked = stops.matching(NSPredicate(format: "value == %@", standing ? "The train is here" : "Next stop"))
        // The page opens scrolled to the train's stop.
        journey.wait(for: marked.firstMatch, "the train's stop", on: "Train", timeout: 3, file: file, line: line)
        XCTAssertEqual(
            marked.count, 1,
            "Train: \(marked.count) stops are marked as where the train is: "
                + stops.allElementsBoundByIndex.map { "\($0.label) = \($0.value ?? "")" }.joined(separator: "; "),
            file: file, line: line)
    }

    /// Lines in the panel; Close in a sheet.
    func back(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Train.back), "the way back", on: "Train", file: file, line: line).tap()
    }
}
