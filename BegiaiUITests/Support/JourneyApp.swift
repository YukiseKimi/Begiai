import XCTest

@MainActor
struct JourneyApp {
    nonisolated static let sealedNow = "2026-11-17T15:55:00Z"
    /// The timetable of 17 Nov 2026 that every journey uses, so a fresh shipped timetable
    /// does not move the trains that the journeys expect. The simulator reads it in place.
    nonisolated static let frozenTimetable = URL(filePath: #filePath)
        .deletingLastPathComponent().appending(path: "../../Fixtures/timetable-20261117.json").standardizedFileURL.path

    let app = XCUIApplication()
    private let clock = Clock()

    private final class Clock {
        var now = JourneyApp.sealedNow
    }

    enum Opening {
        case map
        /// The welcome sheet of a first launch; it needs --welcome in a sealed launch.
        case welcome

        var page: String {
            switch self {
            case .map: A11yID.Map.page
            case .welcome: A11yID.Welcome.title
            }
        }

        var arguments: [String] { self == .welcome ? ["--welcome"] : [] }
    }

    /// `largeText` starts the app at the largest accessibility text size, whatever the simulator's setting.
    func launch(
        _ opening: Opening = .map, at now: String = sealedNow, largeText: Bool = false, file: StaticString = #filePath,
        line: UInt = #line
    ) {
        clock.now = now
        let text = largeText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []
        start(opening, now: now, arguments: ["--reset"] + opening.arguments + text, file: file, line: line)
    }

    /// Starts the app again with its stars and settings. `welcome` asks for the welcome
    /// sheet, which shows only if the user never closed it.
    func relaunch(_ opening: Opening = .map, welcome: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        app.terminate()
        start(opening, now: clock.now, arguments: welcome ? ["--welcome"] : [], file: file, line: line)
    }

    private func start(_ opening: Opening, now: String, arguments: [String], file: StaticString, line: UInt) {
        FailureScreens.watch()
        app.launchArguments = ["--sealed", "--now", now, "--timetable", Self.frozenTimetable] + arguments
        app.launch()
        wait(for: element(opening.page), "the opening's page", on: "Launch", timeout: 15, file: file, line: line)
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }

    @discardableResult
    func wait(
        for element: XCUIElement, _ what: String, on screen: String, timeout: TimeInterval = 10,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        XCTAssertTrue(
            element.exists || element.waitForExistence(timeout: timeout),
            "\(screen): \(what) never appeared", file: file, line: line)
        return element
    }

    func holdLastScreen() {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "the last screen")], timeout: 1)
    }
}
