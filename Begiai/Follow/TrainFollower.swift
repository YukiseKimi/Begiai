import ActivityKit
import BegiaiKit
import Foundation
import Observation
import os

/// The train the rider follows, and its Live Activity on the Lock Screen and in the Dynamic
/// Island. Follow on a train's page starts it, Follow off ends it, and following another
/// train replaces it. The activity runs on the timetable times it starts with; while the app
/// runs, it also moves the next stop on and ends the activity at the last stop.
@MainActor
@Observable
final class TrainFollower {
    /// The followed train; nil when the rider follows none.
    private(set) var followed: FollowedTrain?
    /// True while a Live Activity shows the followed train: false when Live Activities are
    /// off for the app, or the system refused one.
    private(set) var onLockScreen = false

    /// The ActivityKit work, one step after another, so a quick Follow, Follow off and Follow
    /// again reach the system in that order.
    @ObservationIgnored private var work: Task<Void, Never>?
    @ObservationIgnored private let log = Logger.begiai("follow")

    func isFollowing(trip: String, day: ServiceDate) -> Bool {
        followed?.isTrain(trip: trip, day: day) ?? false
    }

    func follow(_ train: FollowedTrain) {
        followed = train
        enqueue { follower in
            await follower.endAll()
            guard follower.followed == train else { return }
            follower.onLockScreen = follower.start(train)
        }
    }

    func unfollow() {
        followed = nil
        onLockScreen = false
        enqueue { follower in await follower.endAll() }
    }

    /// When the app starts or comes back: ends each activity whose train has arrived, and each
    /// older one that a newer replaced, and takes up the train of the one left. `reset`, from a
    /// sealed launch, ends them all, so each journey starts with none.
    func review(reset: Bool = false) {
        enqueue { follower in
            if reset {
                follower.followed = nil
                follower.onLockScreen = false
                await follower.endAll()
                return
            }
            let activities = LiveActivities.running()
            let now = Date()
            let review = FollowReview(activities: activities.map(\.train), at: now)
            for index in review.ended {
                await LiveActivities.end(activities[index], at: now)
            }
            if follower.followed == nil, let kept = review.followed {
                follower.followed = kept
            }
            await follower.update(at: now)
        }
    }

    /// While the app is on screen: updates the activity at each arrival and departure, and
    /// ends it at the last stop. Returns when no train is followed any more.
    func keepCurrent() async {
        while !Task.isCancelled, let train = followed {
            let change = train.nextChange(after: Date())
            if let change {
                try? await Task.sleep(for: .seconds(max(1, change.timeIntervalSinceNow + 1)))
                guard !Task.isCancelled else { return }
            }
            enqueue { follower in await follower.update(at: Date()) }
            await work?.value
            if change == nil { return }
        }
    }

    private func enqueue(_ step: @escaping @MainActor (TrainFollower) async -> Void) {
        let previous = work
        work = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            await step(self)
        }
    }

    private func start(_ train: FollowedTrain) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.info("Live Activities are off: the train is followed in the app only")
            return false
        }
        do {
            try LiveActivities.start(train, at: Date())
            return true
        } catch {
            log.error("The Live Activity did not start: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    /// Moves the next stop on, or ends the activity once its train has arrived.
    private func update(at now: Date) async {
        for activity in LiveActivities.running() {
            if activity.train.hasArrived(at: now) {
                await LiveActivities.end(activity, at: now)
            } else if activity.status != activity.train.status(at: now) {
                await LiveActivities.update(activity, at: now)
            }
        }
        if let train = followed, train.hasArrived(at: now) { followed = nil }
        onLockScreen = LiveActivities.running().contains { activity in followed.map(activity.train.isSameTrain) == true }
    }

    private func endAll() async {
        for activity in LiveActivities.running() {
            await LiveActivities.end(activity, at: nil)
        }
    }
}

/// The app's calls to ActivityKit. Its `Activity` is not Sendable, so these calls find each
/// activity again by its id off the main actor, and the follower holds only Sendable copies.
nonisolated private enum LiveActivities {
    struct Running: Sendable {
        let id: String
        let train: FollowedTrain
        let status: FollowedTrain.Status
    }

    /// The activities that still show, oldest first.
    static func running() -> [Running] {
        Activity<FollowedTrain>.activities
            .filter { $0.activityState == .active || $0.activityState == .stale }
            .map { Running(id: $0.id, train: $0.attributes, status: $0.content.state) }
    }

    static func start(_ train: FollowedTrain, at now: Date) throws {
        _ = try Activity.request(
            attributes: train, content: ActivityContent(state: train.status(at: now), staleDate: train.staleDate),
            pushType: nil)
    }

    @concurrent
    static func update(_ running: Running, at now: Date) async {
        let content = ActivityContent(state: running.train.status(at: now), staleDate: running.train.staleDate)
        await activity(running.id)?.update(content)
    }

    /// Ends an activity: with its last status a short while after its train arrives, or
    /// at once with no time, when the rider stops following or follows another train.
    @concurrent
    static func end(_ running: Running, at now: Date?) async {
        let dismissal = now.flatMap(running.train.dismissal)
        let content = now.map { ActivityContent(state: running.train.status(at: $0), staleDate: nil) }
        await activity(running.id)?.end(content, dismissalPolicy: dismissal.map { .after($0) } ?? .immediate)
    }

    private static func activity(_ id: String) -> Activity<FollowedTrain>? {
        Activity<FollowedTrain>.activities.first { $0.id == id }
    }
}
