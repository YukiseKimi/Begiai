import Foundation

/// Rail that several lines share is drawn as one stripe per line, side by side, each
/// `width` points wide, so the band grows with the number of lines.
public enum TrackStripes {
    /// The width of one line's stripe, in points.
    public static let width = 2.0

    /// Where the centre of each of `count` stripes sits, in points left of the track's centre,
    /// in line order: right to left of the way the track's points run.
    public static func offsets(count: Int) -> [Double] {
        (0..<count).map { (Double($0) - Double(count - 1) / 2) * width }
    }

    /// The offsets of `count` stripes on `path`, set so that line order runs from south to
    /// north (or west to east on rail that runs north and south), whichever way the path's
    /// points were stored. Then two pieces of rail that meet keep their colours on one side.
    public static func offsets(count: Int, along path: [Coordinate]) -> [Double] {
        let offsets = offsets(count: count)
        guard let first = path.first, let last = path.last else { return offsets }
        let east = (last.longitude - first.longitude) * cos(first.latitude * .pi / 180)
        let north = last.latitude - first.latitude
        // Going east, left is north; going north, left is west. Flip to keep south-to-north.
        let heading = abs(east) >= abs(north) ? east : -north
        return heading >= 0 ? offsets : offsets.map { -$0 }
    }
}

extension Array where Element == Coordinate {
    /// The line `metres` to the left of this one, or to the right when negative, as seen going
    /// from the first point to the last. Each point moves along the bisector of its two legs,
    /// so both legs' stripes keep their distance; at a hairpin the move is capped at twice it.
    public func offset(by metres: Double) -> [Coordinate] {
        guard count > 1, metres != 0 else { return self }
        let metresPerDegreeNorth = 111_320.0
        /// The unit normal to the left of the leg from `a` to `b`, in metres east and north.
        func leftNormal(_ a: Coordinate, _ b: Coordinate) -> (east: Double, north: Double)? {
            let east = (b.longitude - a.longitude) * metresPerDegreeNorth * cos(a.latitude * .pi / 180)
            let north = (b.latitude - a.latitude) * metresPerDegreeNorth
            let length = (east * east + north * north).squareRoot()
            guard length > 0.01 else { return nil }
            return (-north / length, east / length)
        }
        let legs = indices.dropLast().map { leftNormal(self[$0], self[$0 + 1]) }
        // A point between two legs, or at an end, takes the nearest real leg on each side.
        let before = legs.indices.map { index in legs[...index].last { $0 != nil } ?? nil }
        let after = legs.indices.map { index in legs[index...].first { $0 != nil } ?? nil }
        return indices.map { index in
            let incoming = index > 0 ? before[index - 1] ?? after[index - 1] : nil
            let outgoing = index < legs.count ? after[index] ?? before[index] : nil
            guard let first = incoming ?? outgoing, let second = outgoing ?? incoming else { return self[index] }
            var east = first.east + second.east
            var north = first.north + second.north
            let length = (east * east + north * north).squareRoot()
            let miter: Double
            if length > 0.01 {
                east /= length
                north /= length
                miter = Swift.min(1 / Swift.max(east * first.east + north * first.north, 0.5), 2)
            } else {
                // The rail doubles back: move the point on past the tip, as far as the cap allows.
                (east, north) = (first.north, -first.east)
                miter = 2
            }
            let point = self[index]
            return Coordinate(
                latitude: point.latitude + north * metres * miter / metresPerDegreeNorth,
                longitude: point.longitude + east * metres * miter
                    / (metresPerDegreeNorth * cos(point.latitude * .pi / 180)))
        }
    }
}
