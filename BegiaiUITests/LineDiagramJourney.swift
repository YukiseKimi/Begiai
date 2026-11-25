import XCTest

final class LineDiagramJourney: JourneyCase {
    @MainActor
    func testAtTheLargestTextSizeTheTrainsStayApart() {
        let journey = JourneyApp()
        journey.launch(.map, largeText: true)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        diagram.expectALineWithItsTrains()
        diagram.expectTrainsApart()
    }

    @MainActor
    func testAtTheDefaultTextSizeTheTrainsStayApart() {
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        diagram.expectALineWithItsTrains()
        diagram.expectTrainsApart()
    }

    @MainActor
    func testTheTabOpensOnTheLastLineSeen() {
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        let chosen = diagram.chooseAnotherLine()
        journey.relaunch(.map)
        diagram.open()
        diagram.expectLine(chosen)
    }

    @MainActor
    func testATapOpensTheTrainPageAndTheStationBoard() {
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
    }

    @MainActor
    func testATapOutsideTheSheetClosesIt() {
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        let destination = diagram.openATrain()
        TrainScreen(journey: journey).expectTrain(to: destination)
        diagram.tapAboveTheSheet()
        diagram.expectTheSheetClosed()
    }
}
