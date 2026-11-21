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
        guard case .failed = store.state else {
            Issue.record("state is \(store.state)")
            return
        }
    }
}

@MainActor
@Suite("Timetable store, two copies", .sealed, .timeLimit(.minutes(1)))
struct TimetableStoreFallbackTests {
    @Test func aBrokenSavedCopyFallsBackToTheShippedOne() async throws {
        let folder = try #require(TestWorld.current).folder
        let saved = folder.appending(path: "saved.json")
        let shipped = folder.appending(path: "shipped.json")
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

@MainActor
@Suite("Timetable store, a newer saved copy", .sealed, .timeLimit(.minutes(1)))
struct TimetableStorePendingTests {
    let now = SealedWorld.day

    @Test func aNewerSavedTimetableReplacesTheLoadedOne() async throws {
        let feed = try FakePages(feedDate: 20_261_118).feed()
        let store = try await loadedStore(feedDate: 20_261_117, feed: feed)
        #expect(await feed.refresh(now: now, loaded: 20_261_117) == .saved(feedDate: 20_261_118))
        await store.adoptPending()
        #expect(store.timetable?.feedDate == 20_261_118)
        #expect(store.engine != nil)
        #expect(store.state == .ready)
    }

    @Test func adoptingANewerTimetableRaisesTheRevision() async throws {
        let feed = try FakePages(feedDate: 20_261_118).feed()
        let store = try await loadedStore(feedDate: 20_261_117, feed: feed)
        let loaded = store.revision
        #expect(await feed.refresh(now: now, loaded: 20_261_117) == .saved(feedDate: 20_261_118))
        await store.adoptPending()
        #expect(store.revision != loaded)
    }

    @Test func aPageOpenedDuringTheSwapKeepsTheLoadedTimetableUntilTheNextCall() async throws {
        let feed = try FakePages(feedDate: 20_261_118).feed()
        let store = try await loadedStore(feedDate: 20_261_117, feed: feed)
        let loaded = store.revision
        #expect(await feed.refresh(now: now, loaded: 20_261_117) == .saved(feedDate: 20_261_118))
        await store.adoptPending { false }
        #expect(store.timetable?.feedDate == 20_261_117)
        #expect(store.revision == loaded)
        await store.adoptPending()
        #expect(store.timetable?.feedDate == 20_261_118)
    }

    @Test func aSavedTimetableNoNewerThanTheLoadedOneIsNotUsed() async throws {
        let feed = try FakePages(feedDate: 20_261_118).feed()
        #expect(await feed.refresh(now: now, loaded: 20_261_117) == .saved(feedDate: 20_261_118))
        let store = try await loadedStore(feedDate: 20_261_120, feed: feed)
        await store.adoptPending()
        #expect(store.timetable?.feedDate == 20_261_120)
    }

    @Test func aBrokenNewerSavedTimetableKeepsTheLoadedOne() async throws {
        let feed = try FakePages(feedDate: 20_261_118).feed()
        let store = try await loadedStore(feedDate: 20_261_117, feed: feed)
        #expect(await feed.refresh(now: now, loaded: 20_261_117) == .saved(feedDate: 20_261_118))
        let other = try #require(TestWorld.current).folder.appending(path: "other.json")
        let saved = try #require(await feed.candidates(bundled: try write(feedDate: 20_261_117, to: other)).first)
        var bad = FourStations.timetable
        bad.feedDate = 20_261_118
        bad.trips[0].shape = 9
        try JSONEncoder().encode(bad).write(to: saved)
        await store.adoptPending()
        #expect(store.timetable?.feedDate == 20_261_117)
        #expect(store.state == .ready)
    }

    private func loadedStore(feedDate: Int, feed: TimetableFeed) async throws -> TimetableStore {
        let url = try write(feedDate: feedDate, to: try #require(TestWorld.current).folder.appending(path: "bundled.json"))
        let store = TimetableStore(feed: feed)
        await store.load(from: url)
        try #require(store.state == .ready)
        return store
    }

    private func write(feedDate: Int, to url: URL) throws -> URL {
        var timetable = FourStations.timetable
        timetable.feedDate = feedDate
        try JSONEncoder().encode(timetable).write(to: url)
        return url
    }
}
