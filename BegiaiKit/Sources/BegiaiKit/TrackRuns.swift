import Foundation

/// A piece of rail to draw, with the lines whose trains run on it, sorted by line id.
public struct TrackRun: Sendable, Equatable {
    public var lines: [Int]
    public var coordinates: [Coordinate]

    public init(lines: [Int], coordinates: [Coordinate]) {
        self.lines = lines
        self.coordinates = coordinates
    }
}

extension Timetable {
    /// The rail of all shapes that trips use, each piece drawn once, cut into runs that each
    /// carry the set of lines on them. Shapes of different lines do not share points, so a
    /// piece of rail belongs to a line when one of the line's shapes passes within `reach`
    /// metres of it. In the shipped bundle 99% of the points of one shape that lie near another
    /// lie within 50 m of it; past 50 m the distances are those of rails that part at a junction.
    public func trackRuns(reach: Double = 50) -> [TrackRun] {
        TrackRunBuilder(timetable: self, reach: reach).runs()
    }
}

/// Works on a flat projection in metres, with the shapes cut into pieces of at most `step`
/// metres. Longest shape first, a piece is kept when no kept piece lies within `reach`; each
/// kept piece takes the lines of all shapes within `reach`, and neighbouring kept pieces with
/// the same lines join into one run.
private struct TrackRunBuilder {
    private struct Point {
        var x: Double
        var y: Double
    }

    private struct Piece {
        var start: Point
        var end: Point
        /// The end is a point of the shape, not a cut.
        var endsAtShapePoint: Bool
        var middle: Point { Point(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2) }
        var length: Double { hypot(end.x - start.x, end.y - start.y) }
    }

    /// Items filed by square cells over the box of all pieces.
    private struct Grid {
        private let size = 500.0
        private let minimum: Point
        private let columns: Int
        private let rows: Int
        private var cells: [[Int]]

        init(around pieces: [Piece], margin: Double) {
            var low = pieces.first?.start ?? Point(x: 0, y: 0)
            var high = low
            for piece in pieces {
                low = Point(x: min(low.x, piece.end.x), y: min(low.y, piece.end.y))
                high = Point(x: max(high.x, piece.end.x), y: max(high.y, piece.end.y))
            }
            minimum = Point(x: low.x - margin, y: low.y - margin)
            columns = Int(((high.x + margin - minimum.x) / size).rounded(.down)) + 1
            rows = Int(((high.y + margin - minimum.y) / size).rounded(.down)) + 1
            cells = Array(repeating: [], count: columns * rows)
        }

        /// The items filed under the point's cell.
        func items(at point: Point) -> [Int] {
            cells[column(point.x) * rows + row(point.y)]
        }

        /// Files an item under each cell within `reach` of the box from `a` to `b`, so that a
        /// point's cell holds every item within `reach` of it.
        mutating func insert(_ item: Int, near a: Point, _ b: Point, within reach: Double) {
            let (columns, rows) = span(near: a, b, within: reach)
            for column in columns {
                for row in rows { cells[column * self.rows + row].append(item) }
            }
        }

        func forEachItem(near a: Point, _ b: Point, within reach: Double, _ body: (Int) -> Void) {
            let (columns, rows) = span(near: a, b, within: reach)
            for column in columns {
                for row in rows {
                    for item in cells[column * self.rows + row] { body(item) }
                }
            }
        }

        /// The columns and rows of the cells within `reach` of the box from `a` to `b`.
        private func span(near a: Point, _ b: Point, within reach: Double) -> (ClosedRange<Int>, ClosedRange<Int>) {
            (
                column(min(a.x, b.x) - reach)...column(max(a.x, b.x) + reach),
                row(min(a.y, b.y) - reach)...row(max(a.y, b.y) + reach)
            )
        }

        private func column(_ x: Double) -> Int { min(columns - 1, max(0, Int(((x - minimum.x) / size).rounded(.down)))) }
        private func row(_ y: Double) -> Int { min(rows - 1, max(0, Int(((y - minimum.y) / size).rounded(.down)))) }
    }

    private let step = 50.0
    /// New rail shorter than this between two kept stretches is the same rail drifting just
    /// past `reach`, and lines that change for less than this are the blur of a junction.
    private let shortest = 200.0
    private let reach: Double
    private static let latitudeScale = 110_540.0
    private let longitudeScale: Double
    /// The lines of each distinct shape, longest first, its points and the range of its pieces.
    private let shapes: [(lines: [Int], points: [Point], pieces: Range<Int>)]
    private let pieces: [Piece]

    init(timetable: Timetable, reach: Double) {
        self.reach = reach
        let latitudes = timetable.shapes.flatMap { $0.points.map(\.coordinate.latitude) }
        let middleLatitude = ((latitudes.min() ?? 55) + (latitudes.max() ?? 55)) / 2
        let longitudeScale = 111_320 * cos(middleLatitude * .pi / 180)
        self.longitudeScale = longitudeScale

        // Shapes with the same points, either way round, are one rail.
        var lines: [Int: Set<Int>] = [:]
        var distinct: [[Coordinate]: Int] = [:]
        for trip in timetable.trips.sorted(by: { $0.shape < $1.shape })
        where timetable.shapes.indices.contains(trip.shape) {
            let points = timetable.shapes[trip.shape].points.map(\.coordinate)
            let shape = distinct[points] ?? distinct[points.reversed()] ?? trip.shape
            distinct[points] = shape
            lines[shape, default: []].insert(trip.line)
        }
        let order = lines.keys.sorted { (timetable.shapes[$0].length, $1) > (timetable.shapes[$1].length, $0) }

        var shapes: [(lines: [Int], points: [Point], pieces: Range<Int>)] = []
        var pieces: [Piece] = []
        for index in order {
            let first = pieces.count
            let points = timetable.shapes[index].points.map {
                Point(x: $0.coordinate.longitude * longitudeScale, y: $0.coordinate.latitude * Self.latitudeScale)
            }
            for (start, end) in zip(points, points.dropFirst()) {
                let count = max(1, Int((hypot(end.x - start.x, end.y - start.y) / step).rounded(.up)))
                var from = start
                for cut in 1...count {
                    let t = Double(cut) / Double(count)
                    let to = Point(x: start.x + t * (end.x - start.x), y: start.y + t * (end.y - start.y))
                    pieces.append(Piece(start: from, end: to, endsAtShapePoint: cut == count))
                    from = to
                }
            }
            shapes.append((lines[index, default: []].sorted(), points, first..<pieces.count))
        }
        self.shapes = shapes
        self.pieces = pieces
    }

    func runs() -> [TrackRun] {
        // Which pieces to draw: each shape's stretches that no longer shape has drawn yet.
        var kept = Grid(around: pieces, margin: reach)
        var stretches: [(shape: Int, own: Range<Int>)] = []
        for (number, shape) in shapes.enumerated() {
            var new = shape.pieces.map { index in
                let middle = pieces[index].middle
                return !kept.items(at: middle).contains { distance(from: middle, to: pieces[$0]) <= reach }
            }
            for stretch in Self.stretches(of: new) where isShortGap(stretch, of: new.count, offset: shape.pieces.lowerBound) {
                new.replaceSubrange(stretch, with: repeatElement(false, count: stretch.count))
            }
            for stretch in Self.stretches(of: new) {
                let own = (shape.pieces.lowerBound + stretch.lowerBound)..<(shape.pieces.lowerBound + stretch.upperBound)
                for index in own { kept.insert(index, near: pieces[index].start, pieces[index].end, within: reach) }
                stretches.append((number, own))
            }
        }

        // Which shapes pass within reach of the middle of each drawn piece.
        var middles = Grid(around: pieces, margin: reach)
        for stretch in stretches {
            for index in stretch.own { middles.insert(index, near: pieces[index].middle, pieces[index].middle, within: 0) }
        }
        var shapesNear = [[Int]](repeating: [], count: pieces.count)
        for (number, shape) in shapes.enumerated() {
            for (start, end) in zip(shape.points, shape.points.dropFirst()) {
                let segment = Piece(start: start, end: end, endsAtShapePoint: true)
                middles.forEachItem(near: start, end, within: reach) { drawn in
                    if shapesNear[drawn].last != number, distance(from: pieces[drawn].middle, to: segment) <= reach {
                        shapesNear[drawn].append(number)
                    }
                }
            }
        }

        var runs: [TrackRun] = []
        for (shape, own) in stretches {
            var lines = smoothed(own.map { Set(shapesNear[$0].flatMap { shapes[$0].lines }).sorted() }, along: own)
            // Reach back and on to the rail already drawn, so that a branch meets it.
            var drawn = own
            if own.lowerBound > shapes[shape].pieces.lowerBound {
                drawn = (own.lowerBound - 1)..<own.upperBound
                lines.insert(lines[0], at: 0)
            }
            if own.upperBound < shapes[shape].pieces.upperBound {
                drawn = drawn.lowerBound..<(own.upperBound + 1)
                lines.append(lines[lines.count - 1])
            }
            runs += join(drawn, lines: lines)
        }
        return runs
    }

    /// A short stretch of new pieces with kept rail at both ends.
    private func isShortGap(_ stretch: Range<Int>, of count: Int, offset: Int) -> Bool {
        stretch.lowerBound > 0 && stretch.upperBound < count
            && length(of: (offset + stretch.lowerBound)..<(offset + stretch.upperBound)) < shortest
    }

    private func length(of range: Range<Int>) -> Double {
        range.reduce(0) { $0 + pieces[$1].length }
    }

    /// Gives a stretch of the same lines shorter than `shortest` the lines of its longer
    /// neighbour.
    private func smoothed(_ lines: [[Int]], along range: Range<Int>) -> [[Int]] {
        var spans: [Range<Int>] = []
        var start = 0
        for index in lines.indices where index == lines.count - 1 || lines[index + 1] != lines[index] {
            spans.append(start..<(index + 1))
            start = index + 1
        }
        guard spans.count > 1 else { return lines }
        let lengths = spans.map { length(of: (range.lowerBound + $0.lowerBound)..<(range.lowerBound + $0.upperBound)) }
        var result = lines
        for (number, span) in spans.enumerated() where lengths[number] < shortest {
            let before = number > 0 ? lengths[number - 1] : -1
            let after = number < spans.count - 1 ? lengths[number + 1] : -1
            let neighbour = before >= after ? spans[number - 1] : spans[number + 1]
            result.replaceSubrange(span, with: repeatElement(result[neighbour.lowerBound], count: span.count))
        }
        return result
    }

    private static func stretches(of flags: [Bool]) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var start: Int?
        for (index, flag) in flags.enumerated() {
            if flag, start == nil { start = index }
            if !flag, let first = start {
                result.append(first..<index)
                start = nil
            }
        }
        if let first = start { result.append(first..<flags.count) }
        return result
    }

    /// Joins neighbouring pieces with the same lines; keeps the shape's points and the cuts
    /// where the lines change.
    private func join(_ range: Range<Int>, lines: [[Int]]) -> [TrackRun] {
        var runs: [TrackRun] = []
        for (offset, index) in range.enumerated() {
            let piece = pieces[index]
            if offset == 0 || lines[offset] != lines[offset - 1] {
                runs.append(TrackRun(lines: lines[offset], coordinates: [coordinate(piece.start)]))
            }
            let last = offset == lines.count - 1 || lines[offset] != lines[offset + 1]
            if piece.endsAtShapePoint || last { runs[runs.count - 1].coordinates.append(coordinate(piece.end)) }
        }
        return runs
    }

    private func coordinate(_ point: Point) -> Coordinate {
        Coordinate(latitude: point.y / Self.latitudeScale, longitude: point.x / longitudeScale)
    }

    private func distance(from point: Point, to piece: Piece) -> Double {
        let dx = piece.end.x - piece.start.x
        let dy = piece.end.y - piece.start.y
        let squared = dx * dx + dy * dy
        let t = squared == 0 ? 0 : max(0, min(1, ((point.x - piece.start.x) * dx + (point.y - piece.start.y) * dy) / squared))
        return hypot(point.x - piece.start.x - t * dx, point.y - piece.start.y - t * dy)
    }
}
