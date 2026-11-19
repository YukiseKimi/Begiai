import Foundation

public enum LaunchFlag: String, CaseIterable, Sendable {
    case sealed = "--sealed"
    case reset = "--reset"
    case now = "--now"
    /// Shows the welcome sheet, which a sealed launch otherwise skips.
    case welcome = "--welcome"
}

public struct SealedLaunch: Equatable, Sendable {

    public var now: Date?
    public var reset: Bool
    public var welcome: Bool

    public init(now: Date?, reset: Bool, welcome: Bool = false) {
        self.now = now
        self.reset = reset
        self.welcome = welcome
    }

    public enum Failure: Error, Equatable {
        case unknownFlag(String)
        case badTime(String)
    }

    public static func read(arguments: [String], allowed: Bool) throws(Failure) -> SealedLaunch? {
        guard allowed, arguments.contains(LaunchFlag.sealed.rawValue) else { return nil }
        var launch = SealedLaunch(now: nil, reset: false)
        var rest = arguments.drop { $0 != LaunchFlag.sealed.rawValue }.dropFirst()[...]
        while let word = rest.popFirst() {
            guard let flag = LaunchFlag(rawValue: word) else {
                if word.hasPrefix("--") { throw .unknownFlag(word) }
                continue
            }
            switch flag {
            case .sealed: break
            case .reset: launch.reset = true
            case .welcome: launch.welcome = true
            case .now:
                let text = rest.popFirst() ?? ""
                guard let date = try? Date(text, strategy: .iso8601) else { throw .badTime(text) }
                launch.now = date
            }
        }
        return launch
    }
}
