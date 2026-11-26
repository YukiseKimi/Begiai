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

    /// The station the page names: "At Vievis, leaves …" or "Next: Paneriai at …".
    func place(file: StaticString = #filePath, line: UInt = #line) -> String {
        let now = journey.wait(for: journey.element(A11yID.Train.now), "where the train is", on: "Train", file: file, line: line)
        guard let match = now.label.firstMatch(of: /^(?:At (.+?), leaves|Next: (.+?) at )/) else {
            XCTFail("Train: where the train is reads \(now.label)", file: file, line: line)
            return ""
        }
        return String(match.1 ?? match.2 ?? "")
    }

    /// A tap on where the train is opens that station's board.
    func openPlace(file: StaticString = #filePath, line: UInt = #line) -> String {
        let name = place(file: file, line: line)
        journey.element(A11yID.Train.now).tap()
        return name
    }

    /// The train's route, “Vilnius → Kaunas”: its title after the departure time.
    func route(file: StaticString = #filePath, line: UInt = #line) -> String {
        let title = journey.wait(for: journey.element(A11yID.Train.title), "the train's title", on: "Train", file: file, line: line)
        guard let space = title.label.firstIndex(of: " ") else {
            XCTFail("Train: the title reads \(title.label)", file: file, line: line)
            return ""
        }
        return String(title.label[title.label.index(after: space)...])
    }

    /// Taps Follow, and checks that the button now says the train is followed and on the Lock Screen.
    func follow(file: StaticString = #filePath, line: UInt = #line) {
        let button = journey.wait(for: journey.element(A11yID.Train.follow), "the Follow button", on: "Train", file: file, line: line)
        XCTAssertEqual(button.label, "Follow", "Train: the train is already followed", file: file, line: line)
        button.tap()
        expectButton(.following, file: file, line: line)
    }

    /// Taps Show train, which the button offers once the map was moved away from the followed
    /// train: the map follows the train again, and the train stays on the Lock Screen.
    func showTrain(file: StaticString = #filePath, line: UInt = #line) {
        expectButton(.released, file: file, line: line)
        journey.element(A11yID.Train.follow).tap()
        expectButton(.following, file: file, line: line)
    }

    /// Taps Following, and checks that the button says Follow again, and no more that the
    /// train is on the Lock Screen.
    func unfollow(file: StaticString = #filePath, line: UInt = #line) {
        expectButton(.following, file: file, line: line)
        journey.element(A11yID.Train.follow).tap()
        expectButton(.off, file: file, line: line)
    }

    /// What the Follow button says, and what VoiceOver reads as its value.
    enum Follow {
        /// “Follow”: the train is not followed.
        case off
        /// “Following”, on the Lock Screen: the map keeps the train in the middle.
        case following
        /// “Show train”, still on the Lock Screen: the map was moved away from the train.
        case released

        var label: String {
            switch self {
            case .off: "Follow"
            case .following: "Following"
            case .released: "Show train"
            }
        }

        var onLockScreen: Bool { self != .off }
    }

    /// The button reads `state` within a few seconds: the Live Activity starts a moment after the tap.
    func expectButton(_ state: Follow, file: StaticString = #filePath, line: UInt = #line) {
        let button = journey.wait(for: journey.element(A11yID.Train.follow), "the Follow button", on: "Train", file: file, line: line)
        let lockScreen = "On the Lock Screen"
        let said = NSPredicate(
            format: state.onLockScreen ? "label == %@ AND value == %@" : "label == %@ AND NOT (value == %@)", state.label, lockScreen)
        XCTAssertEqual(
            XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: said, object: button)], timeout: 5), .completed,
            "Train: the Follow button reads \(button.label), \(button.value ?? "no value"), not \(state.label)"
                + (state.onLockScreen ? ", \(lockScreen)" : ""), file: file, line: line)
    }

    /// Lines in the panel; Close in a sheet.
    func back(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: journey.element(A11yID.Train.back), "the way back", on: "Train", file: file, line: line).tap()
    }
}
