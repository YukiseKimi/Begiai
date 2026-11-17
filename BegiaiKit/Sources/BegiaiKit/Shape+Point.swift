import Foundation

extension Shape {
    public func point(atMetres wanted: Double) -> (coordinate: Coordinate, heading: Double) {
        guard points.count > 1 else { return (points.first?.coordinate ?? Coordinate(latitude: 0, longitude: 0), 0) }
        let metres = min(length, max(0, wanted))
        var low = 0, high = points.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if points[middle].metres <= metres { low = middle } else { high = middle }
        }
        let a = points[low], b = points[high]
        let span = b.metres - a.metres
        let u = span > 0 ? (metres - a.metres) / span : 0
        let coordinate = Coordinate(
            latitude: a.coordinate.latitude + (b.coordinate.latitude - a.coordinate.latitude) * u,
            longitude: a.coordinate.longitude + (b.coordinate.longitude - a.coordinate.longitude) * u)
        var (from, to) = (low, high)
        while from > 0, points[from].coordinate == points[to].coordinate { from -= 1 }
        while to < points.count - 1, points[from].coordinate == points[to].coordinate { to += 1 }
        let start = points[from].coordinate, end = points[to].coordinate
        let east = (end.longitude - start.longitude) * cos(start.latitude * .pi / 180)
        let north = end.latitude - start.latitude
        let heading = (atan2(east, north) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        return (coordinate, heading)
    }
}
