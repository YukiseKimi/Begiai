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

    /// A shorter line chosen after a longer one never shows the longer line's train places.
    @MainActor
    func testEachLineOpensFromTheLineBefore() {
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        diagram.chooseEachLine()
        diagram.expectALineWithItsTrains()
    }

    @MainActor
    func testASwipeMovesToTheNextLineAndBack() {
        let journey = JourneyApp()
        journey.launch(.map)

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        let first = diagram.lineName
        let next = diagram.swipeToAnotherLine(left: true)
        XCTAssertNotEqual(next, first)
        diagram.swipeToAnotherLine(left: false)
        diagram.expectLine(first)
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
    func testATapOutsideTheSheetClosesIt() throws {
        let journey = JourneyApp()
        journey.launch(.map)
        try XCTSkipIf(
            MapScreen(journey: journey).hasColumn(),
            "Duo: a train opens in a column, not a sheet; DuoJourney checks that a tap on the diagram closes the column")

        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        let destination = diagram.openATrain()
        TrainScreen(journey: journey).expectTrain(to: destination)
        diagram.tapAboveTheSheet()
        diagram.expectTheSheetClosed()
    }
}
