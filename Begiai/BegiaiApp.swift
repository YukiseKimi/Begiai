import BegiaiKit
import SwiftData
import SwiftUI
import os

@main
struct BegiaiApp: App {
    private let launch = HermeticLaunch.read()
    private let stars: ModelContainer
    @State private var store: TimetableStore
    @State private var follower = TrainFollower()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        stars = launch.starContainer()
        _store = State(initialValue: TimetableStore(feed: launch.feed))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, mayWelcome: launch.mayWelcome)
                .environment(\.timeSource, launch.time)
                .environment(follower)
                .defaultAppStorage(launch.settings)
                .task { await TipJar.finishUnfinished() }
                .task { follower.review(reset: launch.endsActivities) }
                // While the app is on screen, the followed train's activity moves on stop by stop.
                .task(id: FollowRun(active: scenePhase == .active, train: follower.followed)) {
                    guard scenePhase == .active else { return }
                    await follower.keepCurrent()
                }
                .task {
                    let bundled = launch.timetable ?? Bundle.main.bundleURL.appending(path: "timetable.json")
                    let candidates = await launch.feed?.candidates(bundled: bundled) ?? [bundled]
                    await store.load(from: candidates)
                    await refreshFeed()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    follower.review()
                    Task { await refreshFeed() }
                }
        }
        .modelContainer(stars)
    }

    /// Saves a newer timetable if the feed has one, at most one time each day. The store adopts
    /// it only when no train or station is open, so no train jumps while you look at it.
    private func refreshFeed() async {
        guard let feed = launch.feed, let loaded = store.timetable?.feedDate else { return }
        let outcome = await feed.refresh(now: .now, loaded: loaded)
        Logger.begiai("timetable")
            .info("The timetable feed: \(String(describing: outcome), privacy: .public)")
    }
}

private struct FollowRun: Equatable {
    let active: Bool
    let train: FollowedTrain?
}

extension EnvironmentValues {
    @Entry var timeSource: any TimeSource = SystemTime()
}
