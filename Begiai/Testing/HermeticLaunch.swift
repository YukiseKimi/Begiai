import BegiaiKit
import Foundation

enum HermeticLaunch {
    static func timeSource(bundle: Bundle = .main, arguments: [String] = ProcessInfo.processInfo.arguments) -> any TimeSource {
        let allowed = bundle.object(forInfoDictionaryKey: "BegiaiSealedLaunch") as? String == "YES"
        let launch: SealedLaunch?
        do {
            launch = try SealedLaunch.read(arguments: arguments, allowed: allowed)
        } catch {
            fatalError("Sealed launch: \(error)")
        }
        guard let now = launch?.now else { return SystemTime() }
        return FixedTime(now: now)
    }
}

private struct FixedTime: TimeSource {
    let now: Date
    var isPinned: Bool { true }
}
