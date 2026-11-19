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

    public init() {}

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
                let (timetable, tracks) = try await Self.decode(url)
                self.tracks = tracks
                self.timetable = timetable
                let engine = MotionEngine(timetable: timetable)
                self.engine = engine
                bigStations = engine.bigStations()
                diagrams = timetable.lines.indices.map { LineDiagram(line: $0, timetable: timetable) }
                state = .ready
                return
            } catch {
                Logger(subsystem: "app.begiai.Begiai", category: "timetable").error(
                    "The timetable \(url.lastPathComponent, privacy: .public) did not load: \(String(describing: error), privacy: .public)")
                problems.append(String(describing: error))
            }
        }
        state = .failed(problems.joined(separator: "; "))
    }

    @concurrent
    private static func decode(_ url: URL) async throws -> (Timetable, [Track]) {
        let timetable = try JSONDecoder().decode(Timetable.self, from: Data(contentsOf: url))
        try timetable.check()
        let tracks = timetable.trackRuns().enumerated().map { index, run in
            Track(
                id: index, lines: run.lines,
                coordinates: run.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
        }
        return (timetable, tracks)
    }
}
