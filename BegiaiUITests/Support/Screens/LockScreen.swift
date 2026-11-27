import XCTest

/// The followed train's Live Activity, as the system shows it outside the app. XCUITest
/// reads the Lock Screen presentation in the Notification Centre, which a swipe down from
/// the top left opens, and the compact Dynamic Island's VoiceOver labels over the Home Screen.
@MainActor
struct LockScreen {
    let journey: JourneyApp
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private var titles: XCUIElementQuery {
        springboard.descendants(matching: .any).matching(identifier: A11yID.LiveActivity.title)
    }

    /// Leaves the app and pulls down the Notification Centre, from the top left of the screen.
    /// Measured in a window's frame, as the elements are: on the open iPhone Duo, held wide, the
    /// springboard's own frame is 466 × 678 points, so a spot worked out from it lands elsewhere.
    func open(file: StaticString = #filePath, line: UInt = #line) {
        XCUIDevice.shared.press(.home)
        let window = springboard.windows.firstMatch
        journey.wait(for: window, "the Home Screen", on: "Lock Screen", file: file, line: line)
        let size = window.frame.size
        let top = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: size.width * 0.2, dy: 1))
        top.press(forDuration: 0.1, thenDragTo: top.withOffset(CGVector(dx: 0, dy: size.height * 0.7)))
        // iOS 27 names the list of the Notification Centre; iOS 26 only its window.
        let centre = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier IN %@", ["combined-list-view", "SBCoverSheetWindow"])).firstMatch
        journey.wait(for: centre, "the Notification Centre", on: "Lock Screen", file: file, line: line)
    }

    /// The one Live Activity of the app shows this route, and the next stop or the stop the
    /// train stands at.
    func expectActivity(route: String, place: String, file: StaticString = #filePath, line: UInt = #line) {
        let title = journey.wait(for: titles.firstMatch, "the Live Activity", on: "Lock Screen", file: file, line: line)
        XCTAssertEqual(titles.count, 1, "Lock Screen: \(titles.count) Live Activities of the app show", file: file, line: line)
        XCTAssertEqual(title.label, route, "Lock Screen: the Live Activity is of another train", file: file, line: line)
        let next = springboard.descendants(matching: .any).matching(identifier: A11yID.LiveActivity.next).firstMatch
        XCTAssertTrue(
            next.label.contains(place), "Lock Screen: the Live Activity reads \(next.label), not \(place)", file: file, line: line)
        let bar = springboard.descendants(matching: .any).matching(identifier: A11yID.LiveActivity.bar).firstMatch
        XCTAssertTrue(
            bar.label.hasSuffix("stops passed"), "Lock Screen: the journey bar reads \(bar.label)", file: file, line: line)
    }

    /// The compact Dynamic Island's trailing side reads, for VoiceOver, the train's last stop and
    /// the time left to it in words, “Kaunas, 34 minutes”. It leaves the app for the Home Screen.
    func expectIsland(destination: String, file: StaticString = #filePath, line: UInt = #line) {
        XCUIDevice.shared.press(.home)
        let end = journey.wait(
            for: springboard.descendants(matching: .any).matching(identifier: A11yID.LiveActivity.compactEnd).firstMatch,
            "the last stop and the minutes left", on: "Dynamic Island", file: file, line: line)
        XCTAssertTrue(
            end.label.hasPrefix("\(destination), "), "Dynamic Island: it reads \(end.label), not \(destination) first",
            file: file, line: line)
        XCTAssertNotNil(
            end.label.firstMatch(of: /\d+ (minute|hour)/), "Dynamic Island: \(end.label) says no minutes left",
            file: file, line: line)
    }

    /// No Live Activity of the app shows, within a few seconds of the Notification Centre opening.
    func expectNoActivity(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(
            titles.firstMatch.waitForExistence(timeout: 3), "Lock Screen: a Live Activity still shows: \(titles.firstMatch.label)",
            file: file, line: line)
    }

    /// Taps the Live Activity, which opens the app on its train.
    func openActivity(file: StaticString = #filePath, line: UInt = #line) {
        journey.wait(for: titles.firstMatch, "the Live Activity", on: "Lock Screen", file: file, line: line).tap()
        XCTAssertTrue(
            journey.app.wait(for: .runningForeground, timeout: 10), "Lock Screen: a tap on the Live Activity did not open the app",
            file: file, line: line)
    }

    /// Ends every Live Activity of the app: a sealed launch with --reset does, then the app quits.
    static func endActivities() {
        let journey = JourneyApp()
        journey.launch(.map)
        journey.app.terminate()
    }

    /// Back to the app, where it was.
    func close() {
        journey.app.activate()
    }
}
