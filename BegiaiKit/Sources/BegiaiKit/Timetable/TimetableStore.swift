import CoreLocation
import Foundation
import Observation
import os

@MainActor
@Observable
public final class TimetableStore {
    public enum State: Equatable {
        case loading
        case ready
        case failed(String)
    }

    /// A piece of rail, drawn once, with the lines whose trains run on it, sorted by line id.
    public struct Track: Identifiable, Sendable {
        public let id: Int
        public let lines: [Int]
        public let coordinates: [CLLocationCoordinate2D]
    }

    public private(set) var state: State = .loading
    public private(set) var timetable: Timetable?
    public private(set) var engine: MotionEngine?
    public private(set) var tracks: [Track] = []
    public private(set) var bigStations: Set<Int> = []
    /// The diagram of each line, by line index.
    public private(set) var diagrams: [LineDiagram] = []
    /// The palette slot of each line, by line index: lines that share track differ.
    public private(set) var lineColours: [Int] = []
    /// Goes up by one each time a timetable is shown, so views that keep work made from the
    /// last one (trains, stripes) know to make it again.
    public private(set) var revision = 0

    private let feed: TimetableFeed?

    public init(feed: TimetableFeed? = nil) {
        self.feed = feed
    }

    public func load(from url: URL) async {
        await load(from: [url])
    }

    /// Loads the first timetable in `urls` that decodes and passes its check: a saved copy
    /// that is broken falls back to the one that the app ships.
    public func load(from urls: [URL]) async {
        guard state == .loading, timetable == nil else { return }
        var problems: [String] = []
        for url in urls {
            do {
                let (timetable, tracks, lineColours) = try await Self.decode(url)
                show(timetable, tracks: tracks, lineColours: lineColours)
                state = .ready
                return
            } catch {
                Logger.begiai("timetable").error(
                    "The timetable \(url.lastPathComponent, privacy: .public) did not load: \(String(describing: error), privacy: .public)")
                problems.append(String(describing: error))
            }
        }
        state = .failed(problems.joined(separator: "; "))
    }

    /// Swaps in the timetable that the feed saved, if it is newer than the loaded one. A saved
    /// copy that does not decode or pass its check leaves the loaded timetable in place.
    /// `stillIdle` is asked just before the swap: when it says no, the loaded timetable stays
    /// and the saved copy waits for the next call.
    public func adoptPending(stillIdle: @MainActor () -> Bool = { true }) async {
        guard state == .ready, let feed, let loaded = timetable?.feedDate,
            let url = await feed.pending(newerThan: loaded)
        else { return }
        do {
            let (timetable, tracks, lineColours) = try await Self.decode(url)
            guard let current = self.timetable?.feedDate, timetable.feedDate > current, stillIdle() else { return }
            show(timetable, tracks: tracks, lineColours: lineColours)
        } catch {
            Logger.begiai("timetable").error(
                "The saved timetable \(url.lastPathComponent, privacy: .public) was not adopted: \(String(describing: error), privacy: .public)"
            )
        }
    }

    private func show(_ timetable: Timetable, tracks: [Track], lineColours: [Int]) {
        self.tracks = tracks
        self.lineColours = lineColours
        self.timetable = timetable
        let engine = MotionEngine(timetable: timetable)
        self.engine = engine
        bigStations = engine.bigStations()
        diagrams = timetable.lines.indices.map { LineDiagram(line: $0, timetable: timetable) }
        revision += 1
    }

    @concurrent
    private static func decode(_ url: URL) async throws -> (Timetable, [Track], [Int]) {
        let timetable = try JSONDecoder().decode(Timetable.self, from: Data(contentsOf: url))
        try timetable.check()
        let runs = timetable.trackRuns()
        let tracks = runs.enumerated().map { index, run in
            Track(
                id: index, lines: run.lines,
                coordinates: run.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
        }
        return (timetable, tracks, timetable.lineColours(runs: runs))
    }
}
