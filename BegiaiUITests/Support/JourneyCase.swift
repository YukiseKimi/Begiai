import XCTest

/// A journey stops at its first failure, so the steps after it do not fail for the same cause.
class JourneyCase: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }
}
