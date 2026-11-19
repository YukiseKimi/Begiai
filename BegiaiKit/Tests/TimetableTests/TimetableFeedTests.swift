import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Timetable feed", .sealed, .timeLimit(.minutes(1)))
struct TimetableFeedTests {
    let now = SealedWorld.day
    let shipped = 20261117

    @Test func aNewerBundleIsSavedAndComesFirstAtTheNextLaunch() async throws {
        let pages = try FakePages(feedDate: 20261118)
        let feed = try pages.feed()
        #expect(await feed.refresh(now: now, loaded: shipped) == .saved(feedDate: 20261118))
        let bundled = try writeBundled()
        let first = try #require(await feed.candidates(bundled: bundled).first)
        #expect(first != bundled)
        #expect(try JSONDecoder().decode(Timetable.self, from: Data(contentsOf: first)).feedDate == 20261118)
    }

    @Test func aBundleNoNewerThanTheLoadedOneIsNotDownloaded() async throws {
        let pages = try FakePages(feedDate: shipped)
        #expect(try await pages.feed().refresh(now: now, loaded: shipped) == .upToDate)
        #expect(pages.requests() == ["manifest.json"])
    }

    @Test func aBundleOfAnotherFormatIsNotDownloaded() async throws {
        let pages = try FakePages(feedDate: 20261118, format: Timetable.format + 1)
        #expect(try await pages.feed().refresh(now: now, loaded: shipped) == .upToDate)
        #expect(pages.requests() == ["manifest.json"])
    }

    @Test func aBundleThatIsNotTheOneInTheManifestIsNotSaved() async throws {
        let pages = try FakePages(feedDate: 20261118, tamper: true)
        let feed = try pages.feed()
        guard case .failed = await feed.refresh(now: now, loaded: shipped) else { Issue.record("saved a changed bundle"); return }
        let bundled = try writeBundled()
        #expect(await feed.candidates(bundled: bundled) == [bundled])
    }

    @Test func aBundleThatFailsTheCheckIsNotSaved() async throws {
        var bad = FourStations.timetable
        bad.feedDate = 20261118
        bad.trips[0].line = 7
        let pages = try FakePages(timetable: bad)
        let feed = try pages.feed()
        guard case .failed = await feed.refresh(now: now, loaded: shipped) else { Issue.record("saved a bad bundle"); return }
        let bundled = try writeBundled()
        #expect(await feed.candidates(bundled: bundled) == [bundled])
    }

    @Test func aSavedCopyNoNewerThanTheShippedOneIsNotUsed() async throws {
        let feed = try FakePages(feedDate: 20261118).feed()
        #expect(await feed.refresh(now: now, loaded: shipped) == .saved(feedDate: 20261118))
        let newerApp = try writeBundled(feedDate: 20261120)
        #expect(await feed.candidates(bundled: newerApp) == [newerApp])
    }

    @Test func aClockThatMovesBackChecksAgain() async throws {
        let pages = try FakePages(feedDate: shipped)
        #expect(try await pages.feed().refresh(now: now, loaded: shipped) == .upToDate)
        #expect(try await pages.feed().refresh(now: now.addingTimeInterval(-3600), loaded: shipped) == .upToDate)
        #expect(pages.requests() == ["manifest.json", "manifest.json"])
    }

    @Test func theFeedChecksOneTimeADayButTriesAgainAfterANetworkError() async throws {
        let pages = try FakePages(feedDate: shipped)
        pages.offline(true)
        guard case .failed = try await pages.feed().refresh(now: now, loaded: shipped) else { Issue.record("no error offline"); return }
        pages.offline(false)
        #expect(try await pages.feed().refresh(now: now.addingTimeInterval(60), loaded: shipped) == .upToDate)
        #expect(try await pages.feed().refresh(now: now.addingTimeInterval(3600), loaded: shipped) == .tooSoon)
        #expect(try await pages.feed().refresh(now: now.addingTimeInterval(25 * 3600), loaded: shipped) == .upToDate)
    }

    private func writeBundled(feedDate: Int? = nil) throws -> URL {
        let url = try #require(TestWorld.current).folder.appending(path: "bundled.json")
        var timetable = FourStations.timetable
        timetable.feedDate = feedDate ?? shipped
        try JSONEncoder().encode(timetable).write(to: url)
        return url
    }
}

/// GitHub Pages with one bundle and its manifest, and a log of the files that the feed asked for.
private final class FakePages: @unchecked Sendable {
    private let lock = NSLock()
    private var files: [String: Data]
    private var log: [String] = []
    private var isOffline = false

    convenience init(feedDate: Int, format: Int = Timetable.format, tamper: Bool = false) throws {
        var timetable = FourStations.timetable
        timetable.feedDate = feedDate
        try self.init(timetable: timetable, format: format, tamper: tamper)
    }

    init(timetable: Timetable, format: Int = Timetable.format, tamper: Bool = false) throws {
        let bundle = try JSONEncoder().encode(timetable)
        var manifest = Manifest(bundle: bundle, feedDate: timetable.feedDate)
        manifest.format = format
        var served = bundle
        if tamper { served.append(contentsOf: Data(" ".utf8)) }
        files = ["manifest.json": try JSONEncoder().encode(manifest), "timetable.json": served]
    }

    func feed() throws -> TimetableFeed {
        TimetableFeed(
            base: URL(string: "https://pages.test/")!, folder: try #require(TestWorld.current).folder.appending(path: "Timetable"),
            fetch: { url in try self.serve(url.lastPathComponent) })
    }

    func offline(_ value: Bool) { lock.withLock { isOffline = value } }

    func requests() -> [String] { lock.withLock { log } }

    private func serve(_ name: String) throws -> Data {
        try lock.withLock {
            if isOffline { throw URLError(.notConnectedToInternet) }
            log.append(name)
            guard let data = files[name] else { throw URLError(.fileDoesNotExist) }
            return data
        }
    }
}
