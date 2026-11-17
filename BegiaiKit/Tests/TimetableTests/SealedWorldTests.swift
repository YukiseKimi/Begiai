import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Sealed world", .sealed, .timeLimit(.minutes(1)))
struct SealedWorldTests {
    @Test func theClockStartsAtTheEveningPeakInVilnius() throws {
        let world = try #require(TestWorld.current)
        let parts = Vilnius.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: world.time.now)
        #expect(parts == DateComponents(year: 2026, month: 11, day: 17, hour: 17, minute: 55))
    }
}
