import XCTest

/// Follow on a train's page puts the train on the Lock Screen and in the Dynamic Island.
/// Each test ends with no Live Activity running.
final class LiveActivityJourney: JourneyCase {
    /// Follow starts the Live Activity of that train, a tap on it opens the train's page, and
    /// Follow off ends it.
    @MainActor
    func testFollowPutsTheTrainOnTheLockScreenUntilFollowOff() {
        let journey = JourneyApp()
        journey.launch(.map)
        let map = MapScreen(journey: journey)
        _ = map.openFirstTrain()
        let train = TrainScreen(journey: journey)
        let route = train.route()
        let place = train.place()
        train.follow()
        train.back()
        map.expectNoPage()

        let lockScreen = LockScreen(journey: journey)
        lockScreen.open()
        lockScreen.expectActivity(route: route, place: place)
        lockScreen.openActivity()
        XCTAssertEqual(train.route(), route, "Train: a tap on the Live Activity opened another train")

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
        train.unfollow()
    }

    /// A Live Activity left running makes the next install of the app stop the app that a
    /// test has just launched, and it comes back without its launch arguments. So a test
    /// that fails with a train followed ends its activity: a sealed launch with --reset does.
    override func tearDown() {
        if testRun?.hasSucceeded == false {
            MainActor.assumeIsolated { LockScreen.endActivities() }
        }
        super.tearDown()
    }
}
