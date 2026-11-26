import BegiaiKit
import BegiaiKitTestSupport
import Testing

@Suite("Follow button", .sealed, .timeLimit(.minutes(1)))
struct FollowStateTests {
    @Test func aTrainNotFollowedIsOffWhereverTheMapIs() {
        #expect(FollowState(followed: false, mapFollows: false) == .off)
        // The map can still be on a train that has just arrived and is followed no more.
        #expect(FollowState(followed: false, mapFollows: true) == .off)
    }

    @Test func aFollowedTrainIsReleasedOnceTheMapLetsItGo() {
        #expect(FollowState(followed: true, mapFollows: true) == .following)
        #expect(FollowState(followed: true, mapFollows: false) == .released)
    }

    @Test func followStartsBothAndFollowOffEndsBoth() {
        #expect(FollowState.off.tapped == .following)
        #expect(FollowState.following.tapped == .off)
    }

    /// The Lock Screen keeps the train after a drag on the map, so the tap brings the map
    /// back to the train and ends nothing.
    @Test func aTapAfterTheMapWasMovedBringsTheTrainBack() {
        #expect(FollowState.released.tapped == .following)
    }
}
