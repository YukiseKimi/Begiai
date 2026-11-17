import XCTest

@MainActor
final class FailureScreens: NSObject, @MainActor XCTestObservation {
    private static let shared = FailureScreens()
    private static var watching = false
    private var saved: Set<String> = []

    static func watch() {
        guard !watching else { return }
        watching = true
        XCTestObservationCenter.shared.addTestObserver(shared)
    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        saved.remove(testCase.name)
    }

    func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        guard saved.insert(testCase.name).inserted else { return }
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let attachment = XCTAttachment(screenshot: screen.screenshot())
            attachment.name = XCUIScreen.screens.count > 1 ? "failure-\(index)" : "failure"
            attachment.lifetime = .keepAlways
            testCase.add(attachment)
        }
    }
}
