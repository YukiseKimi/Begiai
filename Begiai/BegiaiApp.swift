import BegiaiKit
import SwiftData
import SwiftUI

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
            RootView(store: store)
                .environment(\.timeSource, launch.time)
                .task {
                    await store.load(from: Bundle.main.bundleURL.appending(path: "timetable.json"))
                }
        }
        .modelContainer(stars)
    }
}

extension EnvironmentValues {
    @Entry var timeSource: any TimeSource = SystemTime()
}
