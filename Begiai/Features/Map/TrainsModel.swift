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

    // Read through `moving(for:)` and `settled(for:)`, so no view pairs these trains with a
    // timetable they did not come from.
    private var moving: [TrainState] = []
    private var settled: [TrainState] = []
    /// The train whose page is open, in `moving`: found once each frame, so the map's camera
    /// keys on its place without a search of the trains.
    private var chosen: TrainState?
    private var chosenID: TrainState.ID?
    /// The store revision of the timetable that `moving` and `settled` come from: their trip
    /// numbers index that timetable and no other.
    private var revision: Int?
    /// The time of `settled`; nil until the first update.
    private(set) var now: Date?
    private(set) var cityZoom = false
    private(set) var trainInSight = false
    private(set) var region: MKCoordinateRegion?
    /// The longest frame at which a train in sight moves no more than half a point each frame.
    private(set) var frame = Duration.seconds(1)

    func look(at region: MKCoordinateRegion, distance: Double) {
        // An Observable property does not tell its views of an equal assignment.
        cityZoom = distance < 80_000
        self.region = region
        frame = Self.frame(for: region)
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

    /// The trains of this frame, from the timetable of `revision`: none until the trains of a
    /// newly shown timetable are worked out.
    func moving(for revision: Int) -> [TrainState] {
        self.revision == revision ? moving : []
    }

    /// The train whose page is open, in the trains of this frame, from the timetable of
    /// `revision`.
    func chosen(for revision: Int) -> TrainState? {
        self.revision == revision ? chosen : nil
    }

    /// Opens the page of this train, or of none: from now on each frame finds it.
    func choose(_ id: TrainState.ID?) {
        chosenID = id
        findChosen()
    }

    private func findChosen() {
        chosen = chosenID.flatMap { id in moving.first { $0.id == id } }
    }

    /// The trains of this second, from the timetable of `revision`: none until the trains of a
    /// newly shown timetable are worked out.
    func settled(for revision: Int) -> [TrainState] {
        self.revision == revision ? settled : []
    }

    func run(engine: MotionEngine, revision: Int, time: any TimeSource, pace: Pace) async {
        let clock = ContinuousClock()
        var next = clock.now
        repeat {
            update(engine: engine, revision: revision, at: time.now)
            guard let interval = pace.interval else { return }
            next = max(next.advanced(by: interval), clock.now)
            try? await clock.sleep(until: next)
        } while !Task.isCancelled
    }

    private func update(engine: MotionEngine, revision: Int, at date: Date) {
        moving = engine.trains(at: date)
        findChosen()
        // A new timetable settles at once, so no old trip number outlives it.
        if revision != self.revision || (now.map({ abs(date.timeIntervalSince($0)) >= 0.9 }) ?? true) {
            self.revision = revision
            settled = moving
            now = date
            lookForTrains()
        }
    }

    private func lookForTrains() {
        trainInSight = region.map { region in settled.contains { region.holds($0.coordinate) } } ?? false
    }
}

extension MKCoordinateRegion {
    /// True when the coordinate is in this region or within half a span beyond each edge.
    func holds(_ coordinate: Coordinate) -> Bool {
        abs(coordinate.latitude - center.latitude) < span.latitudeDelta
            && abs(coordinate.longitude - center.longitude) < span.longitudeDelta
    }
}
