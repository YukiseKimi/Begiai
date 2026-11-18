import Foundation

public struct Departure: Identifiable, Equatable, Sendable {
    public struct ID: Hashable, Sendable {
        public let trip: Int
        public let day: ServiceDate
        public let stop: Int
    }

    public let id: ID
    public let time: Date
    public let destination: String
    public let startsHere: Bool
    public let tomorrow: Bool
}

public struct FirstTrain: Equatable, Sendable {
    public let time: Date
    public let origin: String
    public let destination: String
}

extension MotionEngine {
    public func departures(from station: Int, at date: Date, limit: Int = 8) -> [Departure] {
        let today = ServiceDate(date)
        let rows = [today.adding(days: -1), today, today.adding(days: 1)].map(day).flatMap { day in
            day.trips.flatMap { index -> [Departure] in
                let stops = timetable.trips[index].stops
                return stops.indices.dropLast().compactMap { at -> Departure? in
                    guard stops[at].station == station else { return nil }
                    let time = day.zero.addingTimeInterval(schedule(of: index).departures[at])
                    guard time >= date else { return nil }
                    return Departure(
                        id: Departure.ID(trip: index, day: day.date, stop: at), time: time,
                        destination: timetable.stations[stops[stops.count - 1].station].name,
                        startsHere: at == 0, tomorrow: ServiceDate(time) > today)
                }
            }
        }
        return Array(rows.sorted { $0.time < $1.time }.prefix(limit))
    }

    public func firstTrain(after date: Date) -> FirstTrain? {
        let today = ServiceDate(date)
        let candidates = [today.adding(days: -1), today, today.adding(days: 1)].map(day).compactMap {
            day -> FirstTrain? in
            day.trips.compactMap { index -> FirstTrain? in
                let stops = timetable.trips[index].stops
                let time = day.zero.addingTimeInterval(schedule(of: index).departures[0])
                guard time >= date else { return nil }
                return FirstTrain(
                    time: time, origin: timetable.stations[stops[0].station].name,
                    destination: timetable.stations[stops[stops.count - 1].station].name)
            }.min { $0.time < $1.time }
        }
        return candidates.min { $0.time < $1.time }
    }

    public func bigStations(minimumTrips: Int = 10, spacingMetres: Double = 25_000) -> Set<Int> {
        var count = Array(repeating: 0, count: timetable.stations.count)
        for trip in timetable.trips {
            for stop in trip.stops { count[stop.station] += 1 }
        }
        var kept: [Int] = []
        for station in count.indices.sorted(by: { count[$0] > count[$1] }) where count[station] >= minimumTrips {
            let here = timetable.stations[station].coordinate
            if kept.allSatisfy({ timetable.stations[$0].coordinate.metres(to: here) > spacingMetres }) {
                kept.append(station)
            }
        }
        return Set(kept)
    }
}

extension Coordinate {
    public func metres(to other: Coordinate) -> Double {
        let north = (other.latitude - latitude) * 110_540
        let east = (other.longitude - longitude) * 111_320 * cos(latitude * .pi / 180)
        return (north * north + east * east).squareRoot()
    }
}
