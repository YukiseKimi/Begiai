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

    func back(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Train.back), "the Lines button", on: "Train", file: file, line: line).tap()
    }
}
