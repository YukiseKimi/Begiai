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

public enum Vilnius {
    public static let timeZone = TimeZone(identifier: "Europe/Vilnius")!

    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }()
}
