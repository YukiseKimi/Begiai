import BegiaiKit
import Foundation
import SwiftData
import os

struct HermeticLaunch {
    let time: any TimeSource
    let starFolder: URL?
    /// Where `@AppStorage` keeps the app's settings: a suite of its own in a sealed launch.
    let settings: UserDefaults
    /// Where the app gets a newer timetable. A sealed launch has none, so it never goes to the network.
    let feed: TimetableFeed?
    /// False in a sealed launch without --welcome, so that the journeys start on the map.
    let mayWelcome: Bool
    /// The timetable to load instead of the shipped one: only a sealed launch sets it.
    let timetable: URL?

    private static let sealedSettings = "app.begiai.Begiai.sealed"

    static func read(bundle: Bundle = .main, arguments: [String] = ProcessInfo.processInfo.arguments) -> HermeticLaunch {
        let allowed = bundle.object(forInfoDictionaryKey: "BegiaiSealedLaunch") as? String == "YES"
        let launch: SealedLaunch?
        do {
            launch = try SealedLaunch.read(arguments: arguments, allowed: allowed)
        } catch {
            fatalError("Sealed launch: \(error)")
        }
        guard let launch else {
            // Caches: no iCloud backup for a file that the app can download again, and if iOS
            // clears it, the app falls back to the copy that it ships.
            let folder = URL.cachesDirectory.appending(path: "Timetable", directoryHint: .isDirectory)
            return HermeticLaunch(time: SystemTime(), starFolder: nil, settings: .standard, feed: TimetableFeed(folder: folder),
                mayWelcome: true, timetable: nil)
        }
        let folder = FileManager.default.temporaryDirectory.appending(path: "BegiaiSealed", directoryHint: .isDirectory)
        guard let settings = UserDefaults(suiteName: sealedSettings) else { fatalError("Sealed launch: no settings suite") }
        if launch.reset {
            try? FileManager.default.removeItem(at: folder)
            settings.removePersistentDomain(forName: sealedSettings)
        }
        let time: any TimeSource = launch.now.map { FixedTime(now: $0) } ?? SystemTime()
        return HermeticLaunch(time: time, starFolder: folder, settings: settings, feed: nil, mayWelcome: launch.welcome, timetable: launch.timetable)
    }

    func starContainer() -> ModelContainer {
        do {
            return try StarStorage.container(sealedFolder: starFolder)
        } catch {
            Logger(subsystem: "app.begiai.Begiai", category: "stars")
                .fault("The star store did not open; stars stay in memory: \(String(describing: error), privacy: .public)")
            do {
                return try ModelContainer(for: Star.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            } catch {
                fatalError("No star store can open: \(error)")
            }
        }
    }
}

private struct FixedTime: TimeSource {
    let now: Date
    var isPinned: Bool { true }
}
