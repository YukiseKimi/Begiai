import XCTest

/// Screenshots of the real Live Activity, not a journey: it runs only when
/// `TEST_RUNNER_BEGIAI_ACTIVITY_SHOTS` names a folder, so the journey lane skips it. Set the
/// simulator's appearance first (`xcrun simctl ui <udid> appearance dark`), then run
/// `TEST_RUNNER_BEGIAI_ACTIVITY_SHOTS=<folder> script/test.sh journey LiveActivityShots`.
final class LiveActivityShots: JourneyCase {
    private var folder: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let path = ProcessInfo.processInfo.environment["BEGIAI_ACTIVITY_SHOTS"] ?? ""
        try XCTSkipIf(path.isEmpty, "Live Activity shots: set TEST_RUNNER_BEGIAI_ACTIVITY_SHOTS to a folder")
        folder = URL(filePath: path, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    /// The compact Dynamic Island over the Home Screen, the expanded one, and the Lock Screen
    /// presentation in the Notification Centre.
    @MainActor
    func testShots() {
        let journey = JourneyApp()
        journey.launch(.map)
        _ = MapScreen(journey: journey).openFirstTrain()
        TrainScreen(journey: journey).follow()

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let island = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "jindo-container-view")).firstMatch
        journey.wait(for: island, "the Dynamic Island", on: "Home Screen")
        save("compact")
        island.press(forDuration: 1.2)
        save("expanded")
        XCUIDevice.shared.press(.home)
        LockScreen(journey: journey).open()
        save("lock-screen")
        LockScreen(journey: journey).close()
    }

    private func save(_ name: String) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: 1.5)
        let shot = XCUIScreen.main.screenshot()
        XCTAssertNoThrow(try shot.pngRepresentation.write(to: folder.appending(path: "\(name).png")))
    }
}
