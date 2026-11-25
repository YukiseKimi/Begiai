import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Sealed world", .timeLimit(.minutes(1)))
struct SealedWorldTests {
    /// The journeys and their comments count on this: 15:55 UTC is 17:55 in Vilnius.
    @Test func theSealedTimeIsTheEveningPeakInVilnius() {
        let parts = Vilnius.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: SealedWorld.day)
        #expect(parts == DateComponents(year: 2026, month: 11, day: 17, hour: 17, minute: 55))
    }
}
