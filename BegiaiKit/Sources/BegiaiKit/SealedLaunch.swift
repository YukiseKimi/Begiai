import Foundation

public enum LaunchFlag: String, CaseIterable, Sendable {
    case sealed = "--sealed"
    case reset = "--reset"
    case now = "--now"
    /// Shows the welcome sheet, which a sealed launch otherwise skips.
    case welcome = "--welcome"
    /// Loads this timetable file instead of the one that the app ships, so the journeys keep
    /// their day when the app ships a fresh timetable.
    case timetable = "--timetable"
    /// Runs the clock this many times faster than real time, from `--now` or the real time,
    /// so a recording of the map shows the trains move.
    case speed = "--speed"
}

public struct SealedLaunch: Equatable, Sendable {

    public var now: Date?
    public var reset: Bool
    public var welcome: Bool
    public var timetable: URL?
    public var speed: Double?

    public init(now: Date?, reset: Bool, welcome: Bool = false, timetable: URL? = nil, speed: Double? = nil) {
        self.now = now
        self.reset = reset
        self.welcome = welcome
        self.timetable = timetable
        self.speed = speed
    }

    public enum Failure: Error, Equatable {
        case unknownFlag(String)
        case badTime(String)
        case noTimetable(String)
        case badSpeed(String)
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
            case .timetable:
                let path = rest.popFirst() ?? ""
                guard path.hasPrefix("/") else { throw .noTimetable(path) }
                launch.timetable = URL(filePath: path)
            case .speed:
                let text = rest.popFirst() ?? ""
                guard let speed = Double(text), speed > 0, speed.isFinite else { throw .badSpeed(text) }
                launch.speed = speed
            case .now:
                let text = rest.popFirst() ?? ""
                guard let date = try? Date(text, strategy: .iso8601) else { throw .badTime(text) }
                launch.now = date
            }
        }
        return launch
    }
}
