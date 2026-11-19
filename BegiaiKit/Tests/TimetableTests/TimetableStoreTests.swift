import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@MainActor
@Suite("Timetable store", .sealed, .timeLimit(.minutes(1)))
struct TimetableStoreTests {
    @Test func theStoreLoadsAShippedTimetable() async throws {
        let url = try #require(TestWorld.current).folder.appending(path: "timetable.json")
        try JSONEncoder().encode(ThreeStops.timetable).write(to: url)
        let store = TimetableStore()
        await store.load(from: url)
        #expect(store.state == .ready)
        #expect(store.timetable?.trips.count == 1)
        #expect(store.tracks.map(\.lines) == [[0]])
    }

    @Test func aBrokenTimetableFailsInsteadOfShowingAnEmptyMap() async throws {
        let url = try #require(TestWorld.current).folder.appending(path: "timetable.json")
        try Data("{}".utf8).write(to: url)
        let store = TimetableStore()
        await store.load(from: url)
        #expect(store.timetable == nil)
        guard case .failed = store.state else { Issue.record("state is \(store.state)"); return }
    }
}
