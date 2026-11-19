import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Track runs", .sealed, .timeLimit(.minutes(1)))
struct TrackRunTests {
    @Test func twoLinesThatShareAMiddleSectionGiveThreeRuns() {
        // Line 0 runs 0–20 km east, line 1 runs 10–30 km east, 15 m to the north and with
        // other points: they share 10–20 km.
        let timetable = Rails.timetable(shapes: [
            (line: 0, points: Rails.east(from: 0, to: 20_000, every: 4_000)),
            (line: 1, points: Rails.east(from: 10_000, to: 30_000, every: 2_500, north: 15)),
        ])
        let runs = timetable.trackRuns()
        #expect(runs.map(\.lines).sorted { $0.lexicographicallyPrecedes($1) } == [[0], [0, 1], [1]])
        let shared = runs.first { $0.lines == [0, 1] }
        #expect(abs((shared?.length ?? 0) - 10_000) < 150)
        #expect(abs(runs.map(\.length).reduce(0, +) - 30_000) < 150)
    }

    @Test func aLineWithTwoShapesOnTheSameRailIsDrawnOnce() {
        // The second shape runs the other way, 20 m to the south, with other points.
        let timetable = Rails.timetable(shapes: [
            (line: 0, points: Rails.east(from: 0, to: 20_000, every: 5_000)),
            (line: 0, points: Rails.east(from: 0, to: 20_000, every: 2_500, north: -20).reversed().map { $0 }),
        ])
        let runs = timetable.trackRuns()
        #expect(runs.map(\.lines) == [[0]])
        #expect(abs((runs.first?.length ?? 0) - 20_000) < 150)
    }

    @Test func aBranchStartsWhereItLeavesTheSharedRail() throws {
        // Line 1 follows line 0 for 10 km, then turns north for 5 km.
        let branch = Rails.east(from: 0, to: 10_000, every: 2_000) + [Rails.point(east: 10_000, north: 5_000)]
        let timetable = Rails.timetable(shapes: [
            (line: 0, points: Rails.east(from: 0, to: 20_000, every: 4_000)),
            (line: 1, points: branch),
        ])
        let runs = timetable.trackRuns()
        let own = try #require(runs.first { $0.lines == [1] })
        // The trunk lies on the parallel 55° N.
        let start = try #require(own.coordinates.first)
        #expect(abs(start.latitude - 55) * 110_540 < 1, "the branch leaves a gap at the junction")
    }

    @Test func theShippedTimetableDrawsTheVilniusKaunasRailOnceForSeveralLines() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../Begiai/timetable.json").standardizedFileURL
        let timetable = try JSONDecoder().decode(Timetable.self, from: Data(contentsOf: url))
        let runs = timetable.trackRuns()
        let kaunas = try #require(timetable.lines.firstIndex { $0.name == "Vilnius – Kaunas" })
        let klaipeda = try #require(timetable.lines.firstIndex { $0.name == "Vilnius – Klaipėda" })
        // Between Vilnius and Kaunas both lines run on one piece of rail, drawn once.
        let shared = runs.filter { $0.lines.contains(kaunas) && $0.lines.contains(klaipeda) }
        #expect(shared.map(\.length).reduce(0, +) > 50_000)
        // Each line's rail is drawn about once: the drawn length is near its longest shape.
        for line in [kaunas, klaipeda] {
            let drawn = runs.filter { $0.lines.contains(line) }.map(\.length).reduce(0, +)
            let longest = timetable.trips.filter { $0.line == line }.map { timetable.shapes[$0.shape].length }.max() ?? 0
            #expect(drawn > longest * 0.95 && drawn < longest * 1.1, "line \(line): \(drawn) m drawn, \(longest) m long")
        }
        #expect(runs.count < 100)
    }
}

extension TrackRun {
    var length: Double {
        zip(coordinates, coordinates.dropFirst()).map { $0.metres(to: $1) }.reduce(0, +)
    }
}

private enum Rails {
    static func point(east: Double, north: Double) -> Coordinate {
        Coordinate(latitude: 55 + north / 110_540, longitude: 24 + east / (111_320 * cos(55 * .pi / 180)))
    }

    static func east(from start: Double, to end: Double, every step: Double, north: Double = 0) -> [Coordinate] {
        stride(from: start, through: end, by: step).map { point(east: $0, north: north) }
    }

    static func timetable(shapes: [(line: Int, points: [Coordinate])]) -> Timetable {
        let lines = Set(shapes.map(\.line)).sorted()
        return Timetable(
            feedDate: 20261117, stations: [],
            lines: lines.map { Line(name: "L\($0)", ends: [], international: false) },
            shapes: shapes.map { shape in
                var metres = 0.0
                var last = shape.points.first
                return Shape(points: shape.points.map { here in
                    metres += last.map { $0.metres(to: here) } ?? 0
                    last = here
                    return ShapePoint(coordinate: here, metres: metres)
                })
            },
            trips: shapes.indices.map {
                Trip(id: "t\($0)", code: "\($0)", line: shapes[$0].line, shape: $0, service: 0, stops: [])
            },
            services: [])
    }
}
