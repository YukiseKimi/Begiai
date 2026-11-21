import Foundation

public protocol TimeSource: Sendable {
    var now: Date { get }
    var isPinned: Bool { get }
}

extension TimeSource {
    public var isPinned: Bool { false }
}

public struct SystemTime: TimeSource {
    public init() {}
    public var now: Date { Date() }
}

/// A clock that starts at `start` when the app launches and runs `speed` times faster than
/// real time. Only a sealed launch with `--speed` uses it, to record the map.
public struct FastClock: TimeSource {
    public let start: Date
    public let speed: Double
    public let began: Date

    public init(start: Date, speed: Double, began: Date = Date()) {
        self.start = start
        self.speed = speed
        self.began = began
    }

    public func time(at real: Date) -> Date {
        start.addingTimeInterval(real.timeIntervalSince(began) * speed)
    }

    public var now: Date { time(at: Date()) }
}

public enum Vilnius {
    public static let timeZone = TimeZone(identifier: "Europe/Vilnius")!

    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()
}
