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
        _ = MapScreen(journey: journey).openFirstTrain()
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
    func testATapOnTheMapClosesThePageThenLowersThePanel() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)

        let destination = map.openFirstTrain()
        TrainScreen(journey: journey).expectTrain(to: destination)
        map.tapOutsideThePanel()
        map.expectNoPage()
        map.expectPanel("Half")
        map.tapOutsideThePanel()
        map.expectPanel("Small")
    }
}
