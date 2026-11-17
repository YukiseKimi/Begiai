import BegiaiKit
import SwiftUI

@main
struct BegiaiApp: App {
    private let time = HermeticLaunch.timeSource()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.timeSource, time)
        }
    }
}

extension EnvironmentValues {
    @Entry var timeSource: any TimeSource = SystemTime()
}
