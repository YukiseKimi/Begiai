import XCTest

/// Screenshots of the real Live Activity, not a journey: it runs only when
/// `TEST_RUNNER_BEGIAI_ACTIVITY_SHOTS` names a folder, so the journey lane skips it. Set the
/// simulator's appearance first (`xcrun simctl ui <udid> appearance dark`), then run
/// `TEST_RUNNER_BEGIAI_ACTIVITY_SHOTS=<folder> script/test.sh journey LiveActivityShots`.
/// The activity takes the simulator's language; `TEST_RUNNER_BEGIAI_ACTIVITY_LOCALE=lt_LT` runs
/// the app in it too, as on a Lithuanian iPhone. `TEST_RUNNER_BEGIAI_ACTIVITY_TO=Klaipėda` follows
/// a train to that station, or to the first of `Panevėžys|Kybartai` that a tap opens, and
/// `TEST_RUNNER_BEGIAI_ACTIVITY_NOW` sets the sealed time: at 2026-11-17T17:45:00Z, Klaipėda is
/// over an hour away, and Panevėžys, Kybartai and Turmantas under half an hour.
/// `TEST_RUNNER_BEGIAI_ACTIVITY_WAIT=100` waits that many seconds on the Home Screen first, so a
/// train due then is in: at 2026-11-17T09:32:30Z, Rīgas Centrālā stacija is 90 seconds away.
final class LiveActivityShots: JourneyCase {
    private var folder: URL!
    private var locale: String?
    private var destinations: [String] = []
    private var now = JourneyApp.sealedNow
    private var wait: TimeInterval = 0

    override func setUpWithError() throws {
        try super.setUpWithError()
        let environment = ProcessInfo.processInfo.environment
        let path = environment["BEGIAI_ACTIVITY_SHOTS"] ?? ""
        try XCTSkipIf(path.isEmpty, "Live Activity shots: set TEST_RUNNER_BEGIAI_ACTIVITY_SHOTS to a folder")
        folder = URL(filePath: path, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        locale = environment["BEGIAI_ACTIVITY_LOCALE"].flatMap { $0.isEmpty ? nil : $0 }
        destinations = (environment["BEGIAI_ACTIVITY_TO"] ?? "").split(separator: "|").map(String.init)
        now = environment["BEGIAI_ACTIVITY_NOW"].flatMap { $0.isEmpty ? nil : $0 } ?? now
        wait = environment["BEGIAI_ACTIVITY_WAIT"].flatMap(TimeInterval.init) ?? 0
        executionTimeAllowance = 120 + wait
    }

    /// The compact Dynamic Island over the Home Screen, the expanded one, and the Lock Screen
    /// presentation in the Notification Centre. It reads only station names, so it runs in any
    /// language.
    @MainActor
    func testShots() {
        let journey = JourneyApp(locale: locale)
        journey.launch(.map, at: now)
        MapScreen(journey: journey).openFirstTrain(to: destinations)
        let follow = journey.wait(for: journey.element(A11yID.Train.follow), "the Follow button", on: "Train")
        follow.tap()
        // Starting the activity takes a moment.
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "start")], timeout: 2)

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let island = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "jindo-container-view")).firstMatch
        journey.wait(for: island, "the Dynamic Island", on: "Home Screen")
        if wait > 0 { _ = XCTWaiter.wait(for: [XCTestExpectation(description: "arrive")], timeout: wait) }
        // The island blurs while the Home Screen comes in.
        save("compact", settle: 3)
        island.press(forDuration: 1.2)
        save("expanded")
        XCUIDevice.shared.press(.home)
        LockScreen(journey: journey).open()
        save("lock-screen")
        LockScreen(journey: journey).close()
        // A Live Activity left running upsets the next install: see LiveActivityJourney.
        journey.wait(for: follow, "the Follow button", on: "Train").tap()
    }

    private func save(_ name: String, settle: TimeInterval = 1.5) {
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "settle")], timeout: settle)
        let shot = XCUIScreen.main.screenshot()
        XCTAssertNoThrow(try shot.pngRepresentation.write(to: folder.appending(path: "\(name).png")))
    }
}
