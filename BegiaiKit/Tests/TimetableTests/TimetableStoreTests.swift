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

@MainActor
@Suite("Timetable store, two copies", .sealed, .timeLimit(.minutes(1)))
struct TimetableStoreFallbackTests {
    @Test func aBrokenSavedCopyFallsBackToTheShippedOne() async throws {
        let folder = try #require(TestWorld.current).folder
        let saved = folder.appending(path: "saved.json"), shipped = folder.appending(path: "shipped.json")
        var bad = FourStations.timetable
        bad.trips[0].shape = 9
        try JSONEncoder().encode(bad).write(to: saved)
        try JSONEncoder().encode(FourStations.timetable).write(to: shipped)
        let store = TimetableStore()
        await store.load(from: [saved, shipped])
        #expect(store.state == .ready)
        #expect(store.timetable == FourStations.timetable)
    }
}
