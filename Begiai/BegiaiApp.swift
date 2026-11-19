import BegiaiKit
import SwiftData
import SwiftUI
import os

@main
struct BegiaiApp: App {
    private let launch = HermeticLaunch.read()
    private let stars: ModelContainer
    @State private var store = TimetableStore()

    init() {
        stars = launch.starContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, mayWelcome: launch.mayWelcome)
                .environment(\.timeSource, launch.time)
                .defaultAppStorage(launch.settings)
                .task { await TipJar.finishUnfinished() }
                .task {
                    let bundled = Bundle.main.bundleURL.appending(path: "timetable.json")
                    let candidates = await launch.feed?.candidates(bundled: bundled) ?? [bundled]
                    await store.load(from: candidates)
                    guard let feed = launch.feed, let loaded = store.timetable?.feedDate else { return }
                    // A newer timetable is used at the next launch, so no train jumps while you look at it.
                    let outcome = await feed.refresh(now: .now, loaded: loaded)
                    Logger(subsystem: "app.begiai.Begiai", category: "timetable")
                        .info("The timetable feed: \(String(describing: outcome), privacy: .public)")
                }
        }
        .modelContainer(stars)
    }
}

extension EnvironmentValues {
    @Entry var timeSource: any TimeSource = SystemTime()
}
