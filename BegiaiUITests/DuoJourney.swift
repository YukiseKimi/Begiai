import XCTest

/// The open iPhone Duo, and any screen of regular width: the panel is a glass column on the
/// right of the map, and a train or station on the Line Diagram opens in a column of its own.
/// A narrow screen has a sheet instead, so there these journeys skip.
final class DuoJourney: JourneyCase {
    @MainActor
    private func launchWide() throws -> (JourneyApp, MapScreen) {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)
        try XCTSkipUnless(map.hasColumn(), "Duo: this screen is narrow, so the panel is a sheet, not a column")
        return (journey, map)
    }

    @MainActor
    func testATrainOpensInTheColumnAndTheMapFollowsItBesideTheColumn() throws {
        let (journey, map) = try launchWide()
        let column = ColumnScreen(journey: journey, identifier: A11yID.Map.column)
        column.expectOnTheRight()
        column.expectHolds(A11yID.Map.runningCount, "the running count")

        let destination = map.openFirstTrain()
        let train = TrainScreen(journey: journey)
        train.expectTrain(to: destination)
        column.expectHolds(A11yID.Train.title, "the train's title")
        train.follow()
        map.expectTrainFollowed(to: destination)
        // A drag lets the map go; Show train brings the train back beside the column.
        map.dragOutsideThePanel(far: true)
        map.expectTrainLetGo(to: destination)
        train.showTrain()
        map.expectTrainFollowed(to: destination)
        // Follow off ends the Live Activity, which would otherwise outlive the test.
        train.unfollow()
        train.back()
        map.expectNoPage()
        column.expectOnTheRight()
    }

    @MainActor
    func testAStationOpensInTheColumn() throws {
        let (journey, map) = try launchWide()
        let station = map.openStationAboveThePanel()
        BoardScreen(journey: journey).expectBoard(of: station)
        ColumnScreen(journey: journey, identifier: A11yID.Map.column).expectHolds(A11yID.Board.title, "the station's name")
        map.tapOutsideThePanel()
        map.expectNoPage()
    }

    @MainActor
    func testTheLineDiagramOpensATrainAndAStationInAColumn() throws {
        let (journey, _) = try launchWide()
        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        let column = ColumnScreen(journey: journey, identifier: A11yID.LineDiagram.column)
        XCTAssertFalse(column.element.exists, "Line Diagram: a column shows with no train or station open")

        let destination = diagram.openATrain()
        let train = TrainScreen(journey: journey)
        train.expectTrain(to: destination)
        column.expectOnTheRight()
        column.expectHolds(A11yID.Train.title, "the train's title")
        diagram.expectNoFollowButton()
        diagram.expectTheSheetCloses()
        train.back()
        column.expectGone()

        let station = diagram.openAStation()
        BoardScreen(journey: journey).expectBoard(of: station)
        column.expectHolds(A11yID.Board.title, "the station's name")
    }

    /// As a tap on the map closes the map's page, a tap on the diagram closes its column.
    @MainActor
    func testATapOnTheDiagramClosesTheColumn() throws {
        let (journey, _) = try launchWide()
        let diagram = LineDiagramScreen(journey: journey)
        diagram.open()
        let destination = diagram.openATrain()
        TrainScreen(journey: journey).expectTrain(to: destination)
        let column = ColumnScreen(journey: journey, identifier: A11yID.LineDiagram.column)
        column.expectOnTheRight()
        diagram.tapTheDiagramBeside(column.element.frame.minX)
        column.expectGone()
        diagram.expectTheSheetClosed()
        diagram.expectALineWithItsTrains()
    }
}
