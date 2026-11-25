import Foundation

// `vilniusTime` lives in BegiaiWidgets/LineColour.swift, which the app shares with the widgets.

extension Date {
    func minutes(after now: Date) -> Int {
        max(0, Int((timeIntervalSince(now) / 60).rounded(.up)))
    }
}
