import XCTest

@MainActor
struct JourneyApp {
    static let sealedNow = "2026-11-17T15:55:00Z"

    let app = XCUIApplication()

    enum Opening {
        case map

        var page: String {
            switch self {
            case .map: A11yID.Map.page
            }
        }
    }

    func launch(
        _ opening: Opening = .map, flags: [String] = [],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        start(opening, arguments: ["--reset"] + flags, file: file, line: line)
    }

    func relaunch(_ opening: Opening = .map, file: StaticString = #filePath, line: UInt = #line) {
        app.terminate()
        start(opening, arguments: [], file: file, line: line)
    }

    private func start(_ opening: Opening, arguments: [String], file: StaticString, line: UInt) {
        FailureScreens.watch()
        app.launchArguments = ["--sealed", "--now", Self.sealedNow] + arguments
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
