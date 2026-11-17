import BegiaiKit
import SwiftUI

@main
struct BegiaiApp: App {
    private let time = HermeticLaunch.timeSource()
    @State private var store = TimetableStore()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
                .environment(\.timeSource, time)
                .task {
                    await store.load(from: Bundle.main.bundleURL.appending(path: "timetable.json"))
                }
        }
    }
}

extension EnvironmentValues {
    @Entry var timeSource: any TimeSource = SystemTime()
}
