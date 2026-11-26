import XCTest

final class TrainJourney: JourneyCase {
    @MainActor
    func testATappedTrainOpensItsOwnPage() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        let destination = map.openFirstTrain()
        let train = TrainScreen(journey: journey)
        train.expectTrain(to: destination)
        train.expectWhereTheTrainIs()
        train.back()
        map.expectLines()
    }

    @MainActor
    func testWhereTheTrainIsOpensThatStationsBoard() {
        let journey = JourneyApp()
        journey.launch(.map)
        MapScreen(journey: journey).openFirstTrain()
        let station = TrainScreen(journey: journey).openPlace()
        BoardScreen(journey: journey).expectBoard(of: station)
    }

    @MainActor
    func testATrainAtAStationLeadsToTheStation() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)
        guard let station = map.openTrainStandingAtAStation() else {
            XCTFail("Map: at 17:55 no train stands at a big station above the panel")
            return
        }
        map.openStationChip(station)
        BoardScreen(journey: journey).expectBoard(of: station)
    }

    @MainActor
    func testATapOnTheMapClosesThePageThenLowersThePanel() throws {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)
        try XCTSkipIf(map.hasColumn(), "Duo: the column cannot be lowered; DuoJourney checks that a tap on the map closes the page")

        let destination = map.openFirstTrain()
        TrainScreen(journey: journey).expectTrain(to: destination)
        map.tapOutsideThePanel()
        map.expectNoPage()
        map.expectPanel("Half")
        map.tapOutsideThePanel()
        map.expectPanel("Small")
    }

    /// A rider on a moving train drags the map to look around: the train's page stays open.
    @MainActor
    func testADragOnTheMapKeepsThePageOpen() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        let destination = map.openFirstTrain()
        TrainScreen(journey: journey).expectTrain(to: destination)
        map.dragOutsideThePanel()
        TrainScreen(journey: journey).expectTrain(to: destination)
    }

    /// On a moving train the finger slides a little as it taps: the tap still closes the page.
    @MainActor
    func testAShakyTapOnTheMapClosesThePage() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        let destination = map.openFirstTrain()
        TrainScreen(journey: journey).expectTrain(to: destination)
        map.shakyTapOutsideThePanel()
        map.expectNoPage()
    }

    /// A double-tap zooms the map. Its first tap closes the page; its second does not count
    /// again, so the panel stays at its height.
    @MainActor
    func testADoubleTapOnTheMapClosesThePageOnce() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        let destination = map.openFirstTrain()
        TrainScreen(journey: journey).expectTrain(to: destination)
        map.doubleTapOutsideThePanel()
        map.expectNoPage()
        map.expectPanel("Half")
    }

    /// With no page open, a double-tap zooms the map, and its taps do not lower the panel:
    /// that would move the map and stop the zoom.
    @MainActor
    func testADoubleTapOnTheMapZoomsAndKeepsThePanel() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        map.expectPanel("Half")
        let before = map.trainsInSight()
        map.doubleTapOutsideThePanel()
        _ = XCTWaiter.wait(for: [XCTestExpectation(description: "the zoom")], timeout: 1.5)
        map.expectPanel("Half")
        let after = map.trainsInSight()
        XCTAssertLessThan(after, before, "Map: \(after) trains show after a double-tap, \(before) before: it did not zoom")
    }
}
