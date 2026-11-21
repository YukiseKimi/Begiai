import BegiaiKit
import SwiftData
import SwiftUI
import os

@main
struct BegiaiApp: App {
    private let launch = HermeticLaunch.read()
    private let stars: ModelContainer
    @State private var store: TimetableStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        stars = launch.starContainer()
        _store = State(initialValue: TimetableStore(feed: launch.feed))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, mayWelcome: launch.mayWelcome)
                .environment(\.timeSource, launch.time)
                .defaultAppStorage(launch.settings)
                .task { await TipJar.finishUnfinished() }
                .task {
                    let bundled = launch.timetable ?? Bundle.main.bundleURL.appending(path: "timetable.json")
                    let candidates = await launch.feed?.candidates(bundled: bundled) ?? [bundled]
                    await store.load(from: candidates)
                    await refreshFeed()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
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

extension EnvironmentValues {
    @Entry var timeSource: any TimeSource = SystemTime()
}
