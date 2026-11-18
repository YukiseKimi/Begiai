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

    public struct Track: Identifiable, Sendable {
        public let id: Int
        public let line: Int
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
        guard state == .loading, timetable == nil else { return }
        do {
            let timetable = try await Self.decode(url)
            let lines = Dictionary(timetable.trips.map { ($0.shape, $0.line) }, uniquingKeysWith: { first, _ in first })
            tracks = timetable.shapes.indices.compactMap { index in
                guard let line = lines[index] else { return nil }
                let coordinates = timetable.shapes[index].points.map {
                    CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                }
                return Track(id: index, line: line, coordinates: coordinates)
            }
            self.timetable = timetable
            let engine = MotionEngine(timetable: timetable)
            self.engine = engine
            bigStations = engine.bigStations()
            diagrams = timetable.lines.indices.map { LineDiagram(line: $0, timetable: timetable) }
            state = .ready
        } catch {
            Logger(subsystem: "app.begiai.Begiai", category: "timetable").error(
                "The timetable did not load: \(String(describing: error), privacy: .public)")
            state = .failed(String(describing: error))
        }
    }

    @concurrent
    private static func decode(_ url: URL) async throws -> Timetable {
        try JSONDecoder().decode(Timetable.self, from: Data(contentsOf: url))
    }
}
