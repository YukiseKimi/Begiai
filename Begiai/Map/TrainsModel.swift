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
        /// 30 frames a second: city zoom, with a train in sight.
        case smooth
        /// Once a second: country zoom, no train in sight, Reduce Motion or Low Power Mode.
        case second
        /// Once, then no more: a pinned clock, or the app not on screen.
        case still

        var interval: Duration? {
            switch self {
            case .smooth: .seconds(1.0 / 30)
            case .second: .seconds(1)
            case .still: nil
            }
        }
    }

    private(set) var moving: [TrainState] = []
    private(set) var settled: [TrainState] = []
    /// The time of `settled`; nil until the first update.
    private(set) var now: Date?
    private(set) var cityZoom = false
    private(set) var trainInSight = false
    private(set) var region: MKCoordinateRegion?

    func look(at region: MKCoordinateRegion, distance: Double) {
        let city = distance < 80_000
        if city != cityZoom { cityZoom = city }
        self.region = region
        lookForTrains()
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
