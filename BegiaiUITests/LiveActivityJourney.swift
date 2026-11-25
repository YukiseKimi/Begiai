import XCTest

/// Follow on a train's page puts the train on the Lock Screen and in the Dynamic Island.
final class LiveActivityJourney: JourneyCase {
    /// Follow starts the Live Activity of that train; Follow off ends it.
    @MainActor
    func testFollowPutsTheTrainOnTheLockScreenUntilFollowOff() {
        let journey = JourneyApp()
        journey.launch(.map)
        _ = MapScreen(journey: journey).openFirstTrain()
        let train = TrainScreen(journey: journey)
        let route = train.route()
        let place = train.place()
        train.follow()

        let lockScreen = LockScreen(journey: journey)
        lockScreen.open()
        lockScreen.expectActivity(route: route, place: place)
        lockScreen.close()

        train.unfollow()
        lockScreen.open()
        lockScreen.expectNoActivity()
        lockScreen.close()
    }

    /// The followed train outlives a relaunch, and following another train takes its place.
    @MainActor
    func testFollowingAnotherTrainTakesThePlaceOfTheFirst() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)
        _ = map.openFirstTrain()
        let train = TrainScreen(journey: journey)
        let first = train.route()
        train.follow()

        journey.relaunch()
        let second = map.openFirstTrain(otherThan: first)
        let place = train.place()
        train.follow()

        let lockScreen = LockScreen(journey: journey)
        lockScreen.open()
        lockScreen.expectActivity(route: second, place: place)
        lockScreen.close()
    }
}
