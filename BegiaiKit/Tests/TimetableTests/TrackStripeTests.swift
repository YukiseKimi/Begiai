import BegiaiKit
import Foundation
import Testing

@Suite("Track stripes", .sealed, .timeLimit(.minutes(1)))
struct TrackStripeTests {
    /// Metres between two coordinates, on a flat projection, which is exact enough at these distances.
    private func metres(_ a: Coordinate, _ b: Coordinate) -> Double {
        let north = (b.latitude - a.latitude) * 111_320
        let east = (b.longitude - a.longitude) * 111_320 * cos(a.latitude * .pi / 180)
        return (north * north + east * east).squareRoot()
    }

    @Test func theStripesOfAShareSitSideBySideAndCentreOnTheTrack() {
        #expect(TrackStripes.offsets(count: 1) == [0])
        #expect(TrackStripes.offsets(count: 2) == [-1, 1])
        #expect(TrackStripes.offsets(count: 3) == [-2, 0, 2])
        #expect(TrackStripes.offsets(count: 6).first == -5)
        #expect(TrackStripes.offsets(count: 6).last == 5)
    }

    @Test func aStripeOnAStraightTrackRunsParallelAtItsDistance() {
        // East along a parallel near Vilnius: left of the way is north.
        let track = [Coordinate(latitude: 54.6, longitude: 25.0), Coordinate(latitude: 54.6, longitude: 25.1)]
        let left = track.offset(by: 40)
        let right = track.offset(by: -40)
        for (point, moved) in zip(track, left) {
            #expect(abs(metres(point, moved) - 40) < 0.5)
            #expect(moved.latitude > point.latitude)
        }
        for (point, moved) in zip(track, right) {
            #expect(moved.latitude < point.latitude)
        }
    }

    @Test func aStripeKeepsItsDistanceFromBothLegsOfABend() {
        // North, then east: the corner's point moves out along the bisector, so each leg's
        // stripe stays 30 m from its leg.
        let corner = Coordinate(latitude: 54.7, longitude: 25.0)
        let track = [
            Coordinate(latitude: 54.6, longitude: 25.0), corner, Coordinate(latitude: 54.7, longitude: 25.2),
        ]
        let right = track.offset(by: -30)
        let east = (right[1].longitude - corner.longitude) * 111_320 * cos(corner.latitude * .pi / 180)
        let south = (corner.latitude - right[1].latitude) * 111_320
        #expect(abs(east - 30) < 0.5)
        #expect(abs(south - 30) < 0.5)
    }

    @Test func aLineKeepsItsSideWhicheverWayTheRailWasStored() {
        let west = Coordinate(latitude: 54.6, longitude: 25.0)
        let east = Coordinate(latitude: 54.6, longitude: 25.1)
        let eastward = [west, east]
        let westward = [east, west]
        for slot in 0..<3 {
            let one = eastward.offset(by: TrackStripes.offsets(count: 3, along: eastward)[slot] * 10)
            let other = westward.offset(by: TrackStripes.offsets(count: 3, along: westward)[slot] * 10)
            #expect(abs(one[0].latitude - other[1].latitude) < 1e-9)
        }
        // The first line is the southern stripe.
        let first = eastward.offset(by: TrackStripes.offsets(count: 3, along: eastward)[0] * 10)
        #expect(first[0].latitude < west.latitude)
    }

    @Test func onRailThatRunsNorthTheFirstLineIsTheWesternStripeEitherWay() {
        let south = Coordinate(latitude: 54.6, longitude: 25.0)
        let north = Coordinate(latitude: 54.7, longitude: 25.0)
        for path in [[south, north], [north, south]] {
            let first = path.offset(by: TrackStripes.offsets(count: 2, along: path)[0] * 10)
            #expect(first.allSatisfy { $0.longitude < 25.0 })
        }
    }

    @Test func aSharpBendMovesItsPointAtMostTwiceTheDistance() {
        // Up and almost straight back down: the bisector's move is capped at twice the offset.
        let tip = Coordinate(latitude: 54.7, longitude: 25.0)
        let track = [
            Coordinate(latitude: 54.6, longitude: 25.0), tip, Coordinate(latitude: 54.6, longitude: 25.001),
        ]
        let moved = track.offset(by: 20)[1]
        #expect(metres(tip, moved) <= 40.5)
        #expect(metres(tip, moved) > 0)
    }

    @Test func aTrackWithRepeatedPointsStillGetsAStripe() {
        let a = Coordinate(latitude: 54.6, longitude: 25.0)
        let b = Coordinate(latitude: 54.6, longitude: 25.1)
        let left = [a, a, b, b].offset(by: 10)
        #expect(left.count == 4)
        #expect(left.allSatisfy { $0.latitude > 54.6 })
    }
}
