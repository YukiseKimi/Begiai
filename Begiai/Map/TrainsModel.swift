import BegiaiKit
import Foundation
import MapKit
import Observation

/// The running trains, kept at two speeds: the map markers read `moving`, which changes each
/// frame; the panel reads `settled`, which changes once a second.
@MainActor
@Observable
final class TrainsModel {
    enum Pace: Hashable {
        /// An update after each interval.
        case every(Duration)
        /// One update, then no more: a pinned clock, or the app not on screen.
        case still

        var interval: Duration? {
            switch self {
            case .every(let interval): interval
            case .still: nil
            }
        }
    }

    /// The frame intervals the map can use, shortest first.
    private static let frames: [Duration] = [30, 15, 10, 5, 2, 1].map { (perSecond: Double) in .seconds(1 / perSecond) }

    private(set) var moving: [TrainState] = []
    private(set) var settled: [TrainState] = []
    /// The time of `settled`; nil until the first update.
    private(set) var now: Date?
    private(set) var cityZoom = false
    private(set) var trainInSight = false
    private(set) var region: MKCoordinateRegion?
    /// The longest frame at which a train in sight moves no more than half a point each frame.
    private(set) var frame = Duration.seconds(1)

    func look(at region: MKCoordinateRegion, distance: Double) {
        let city = distance < 80_000
        if city != cityZoom { cityZoom = city }
        self.region = region
        let frame = Self.frame(for: region)
        if frame != self.frame { self.frame = frame }
        lookForTrains()
    }

    /// A train at 160 km/h, on a map about 400 points wide, moves this many points each second.
    /// The frame is the longest that keeps each step at or below half a point.
    private static func frame(for region: MKCoordinateRegion) -> Duration {
        let metresWide = region.span.longitudeDelta * 111_320 * cos(region.center.latitude * .pi / 180)
        let pointsPerSecond = (160 / 3.6) / (metresWide / 400)
        let longest = Duration.seconds(min(0.5 / pointsPerSecond, 1))
        return frames.last { $0 <= longest } ?? frames[0]
    }

    func run(engine: MotionEngine, time: any TimeSource, pace: Pace) async {
        let clock = ContinuousClock()
        var next = clock.now
        repeat {
            update(engine: engine, at: time.now)
            guard let interval = pace.interval else { return }
            next = max(next.advanced(by: interval), clock.now)
            try? await clock.sleep(until: next)
        } while !Task.isCancelled
    }

    private func update(engine: MotionEngine, at date: Date) {
        moving = engine.trains(at: date)
        if now.map({ abs(date.timeIntervalSince($0)) >= 0.9 }) ?? true {
            settled = moving
            now = date
            lookForTrains()
        }
    }

    private func lookForTrains() {
        let seen = region.map { region in settled.contains { region.holds($0.coordinate) } } ?? false
        if seen != trainInSight { trainInSight = seen }
    }
}

extension MKCoordinateRegion {
    /// True when the coordinate is in this region or within half a span beyond each edge.
    func holds(_ coordinate: Coordinate) -> Bool {
        abs(coordinate.latitude - center.latitude) < span.latitudeDelta
            && abs(coordinate.longitude - center.longitude) < span.longitudeDelta
    }
}
