import BegiaiKit
import Foundation

struct LocalPlane {
    static let lithuania = LocalPlane(latitude: 55.2)

    let metresPerDegreeLatitude = 110_540.0
    let metresPerDegreeLongitude: Double

    init(latitude: Double) {
        metresPerDegreeLongitude = 111_320 * cos(latitude * .pi / 180)
    }

    func xy(_ c: Coordinate) -> SIMD2<Double> {
        SIMD2(c.longitude * metresPerDegreeLongitude, c.latitude * metresPerDegreeLatitude)
    }

    func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let d = xy(a) - xy(b)
        return (d * d).sum().squareRoot()
    }
}

struct Projection {
    let metres: Double
    let offTrack: Double
}

enum Geometry {
    static func cumulativeMetres(_ points: [Coordinate], plane: LocalPlane = .lithuania) -> [Double] {
        var total = 0.0
        return points.indices.map { index in
            if index > 0 { total += plane.distance(points[index - 1], points[index]) }
            return total
        }
    }

    static func project(
        _ station: Coordinate, onto points: [Coordinate], metres: [Double], from startMetres: Double,
        plane: LocalPlane = .lithuania
    ) -> Projection {
        let p = plane.xy(station)
        var best = Projection(metres: startMetres, offTrack: .infinity)
        for index in 1..<points.count where metres[index] >= startMetres {
            let a = plane.xy(points[index - 1])
            let b = plane.xy(points[index])
            let ab = b - a
            let lengthSquared = (ab * ab).sum()
            let u = lengthSquared > 0 ? min(1, max(0, ((p - a) * ab).sum() / lengthSquared)) : 0
            let foot = a + ab * u
            let off = ((p - foot) * (p - foot)).sum().squareRoot()
            let along = metres[index - 1] + (metres[index] - metres[index - 1]) * u
            if off < best.offTrack - 0.01, along >= startMetres {
                best = Projection(metres: along, offTrack: off)
            }
        }
        if best.offTrack.isFinite { return best }
        let start = points.indices.last { metres[$0] <= startMetres } ?? 0
        return Projection(metres: startMetres, offTrack: plane.distance(station, points[start]))
    }

    static func simplify(_ points: [Coordinate], tolerance: Double, plane: LocalPlane = .lithuania) -> [Int] {
        guard points.count > 2 else { return Array(points.indices) }
        let xy = points.map(plane.xy)
        var keep = Array(repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack = [(0, points.count - 1)]
        while let (first, last) = stack.popLast() {
            let a = xy[first]
            let ab = xy[last] - a
            let lengthSquared = (ab * ab).sum()
            var farthest = (index: -1, distance: 0.0)
            for index in (first + 1)..<last {
                let ap = xy[index] - a
                let u = lengthSquared > 0 ? min(1, max(0, (ap * ab).sum() / lengthSquared)) : 0
                let d = ap - ab * u
                let distance = (d * d).sum().squareRoot()
                if distance > farthest.distance { farthest = (index, distance) }
            }
            if farthest.distance > tolerance {
                keep[farthest.index] = true
                stack.append((first, farthest.index))
                stack.append((farthest.index, last))
            }
        }
        return keep.indices.filter { keep[$0] }
    }
}
