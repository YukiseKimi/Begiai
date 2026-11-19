import XCTest

final class TrainJourney: XCTestCase {
    @MainActor
    func testATappedTrainOpensItsOwnPage() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        let destination = map.openFirstTrain()
        let train = TrainScreen(journey: journey)
        train.expectTrain(to: destination)
        train.expectWhereTheTrainIs()
        train.back()
        map.expectLines()
        journey.holdLastScreen()
    }
}
