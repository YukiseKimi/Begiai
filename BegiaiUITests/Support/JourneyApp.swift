import XCTest

@MainActor
struct JourneyApp {
    nonisolated static let sealedNow = "2026-11-17T15:55:00Z"
    /// The timetable of 17 Nov 2026 that every journey uses, so a fresh shipped timetable
    /// does not move the trains that the journeys expect. The simulator reads it in place.
    nonisolated static let frozenTimetable = URL(filePath: #filePath)
        .deletingLastPathComponent().appending(path: "../../Fixtures/timetable-20261117.json").standardizedFileURL.path

    /// The journeys read English labels, so the app runs in English whatever the simulator's language.
    nonisolated static let english = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

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
    /// `speed` runs the clock that many times faster than real time, for a recording.
    func launch(
        _ opening: Opening = .map, at now: String = sealedNow, largeText: Bool = false, speed: Int? = nil,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        clock.now = now
        let text = largeText ? ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] : []
        let fast = speed.map { ["--speed", String($0)] } ?? []
        start(opening, now: now, arguments: ["--reset"] + opening.arguments + text + fast, file: file, line: line)
    }

    /// Starts the app again with its stars and settings. `welcome` asks for the welcome
    /// sheet, which shows only if the user never closed it.
    func relaunch(_ opening: Opening = .map, welcome: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        app.terminate()
        start(opening, now: clock.now, arguments: welcome ? ["--welcome"] : [], file: file, line: line)
    }

    private func start(_ opening: Opening, now: String, arguments: [String], file: StaticString, line: UInt) {
        FailureScreens.watch()
        app.launchArguments = ["--sealed", "--now", now, "--timetable", Self.frozenTimetable] + Self.english + arguments
        app.launch()
        wait(for: element(opening.page), "the opening's page", on: "Launch", timeout: 15, file: file, line: line)
    }

    /// The tabs. A `Tab` has no identifier to find it by: iOS 27 drops one set with
    /// `accessibilityIdentifier` now and then.
    enum TabPlace: Int {
        case map
        case lineDiagram

        /// The tab's title, in English, as the journeys run the app.
        var title: String {
            switch self {
            case .map: "Map"
            case .lineDiagram: "Line Diagram"
            }
        }
    }

    /// The tab's button, by its place in the tab bar on an iPhone. Where the tabs are not in a
    /// tab bar, such as on the side of an iPhone Duo's screen, by its title among the buttons.
    func tab(_ place: TabPlace) -> XCUIElement {
        let bar = app.tabBars.buttons
        guard !bar.firstMatch.waitForExistence(timeout: 3) else { return bar.element(boundBy: place.rawValue) }
        return app.buttons.matching(NSPredicate(format: "label == %@", place.title)).firstMatch
    }

    /// The app's window. Its frame is the screen as the app lays it out, in the same space as
    /// the elements' frames. The app's own frame is not: on the open iPhone Duo, held wide, it
    /// stays 669 × 951 points, as if upright, while the window and the elements are 951 × 669.
    var window: XCUIElement { app.windows.firstMatch }

    /// The spot `point` points from the window's top left corner, in the elements' space.
    func spot(_ point: CGPoint) -> XCUICoordinate {
        window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y))
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
}
