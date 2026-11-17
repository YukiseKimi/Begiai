import BegiaiKit
import Foundation

extension Date {
    var vilniusTime: String {
        formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: Vilnius.timeZone))
    }

    func minutes(after now: Date) -> Int {
        max(0, Int((timeIntervalSince(now) / 60).rounded(.up)))
    }
}
