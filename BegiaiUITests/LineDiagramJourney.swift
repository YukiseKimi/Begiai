import XCTest

final class LineDiagramJourney: XCTestCase {
    @MainActor
    func testAtTheLargestTextSizeTheTrainsStayApart() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map, largeText: true)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        diagram.expectALineWithItsTrains()
        diagram.expectTrainsApart()
        journey.holdLastScreen()
    }

    @MainActor
    func testTheDiagramShowsATrainBetweenTwoStations() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        diagram.expectALineWithItsTrains()
        journey.holdLastScreen()
    }

    @MainActor
    func testTheTabOpensOnTheLastLineSeen() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        let chosen = diagram.chooseAnotherLine()
        journey.relaunch(.map)
        diagram.open()
        diagram.expectLine(chosen)
        journey.holdLastScreen()
    }

    @MainActor
    func testATapOpensTheTrainPageAndTheStationBoard() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        let destination = diagram.openATrain()
        let train = TrainScreen(journey: journey)
        train.expectTrain(to: destination)
        diagram.expectNoFollowButton()
        diagram.expectTheSheetCloses()
        train.back()
        let station = diagram.openAStation()
        let board = BoardScreen(journey: journey)
        board.expectBoard(of: station)
        // The first station of the busiest line, at 17:55 in Vilnius.
        board.expectMinutesWithinTheHour(now: (17, 55), busy: true)
        journey.holdLastScreen()
    }

    @MainActor
    func testATapOutsideTheSheetClosesIt() {
        continueAfterFailure = false
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        let destination = diagram.openATrain()
        TrainScreen(journey: journey).expectTrain(to: destination)
        diagram.tapAboveTheSheet()
        diagram.expectTheSheetClosed()
        journey.holdLastScreen()
    }
}
