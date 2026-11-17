import BegiaiKit
import Foundation

public struct BundleReport: Sendable, Equatable {
    public var fastSections: [String] = []
    public var worstOffTrack: Double = 0
}

public enum BundleError: Error, CustomStringConvertible {
    case noTrips(agency: String)
    case missingStation(String)
    case missingShape(String)
    case badTime(String)
    case noCalendar

    public var description: String {
        switch self {
        case .noTrips(let agency): "agency \(agency) has no rail trips in the feed"
        case .missingStation(let id): "stop_times names stop \(id), which stops.txt does not have"
        case .missingShape(let id): "trips.txt names shape \(id), which shapes.txt does not have"
        case .badTime(let text): "a stop time is not HH:MM:SS: \(text)"
        case .noCalendar: "the feed has neither calendar.txt nor calendar_dates.txt"
        }
    }
}

public struct BundleBuilder {
    public var agency = "90"
    public var simplifyTolerance = 25.0
    public var fastSectionSpeed = 160.0 / 3.6
    public var internationalStations: Set<String> = ["Rīgas Centrālā stacija"]

    public init() {}

    public func build(feed folder: URL, feedDate: Int) throws -> (Timetable, BundleReport) {
        var report = BundleReport()
        let routes = try readRoutes(folder)
        var gtfsTrips = try readTrips(folder, routes: routes)
        let stopTimes = try readStopTimes(folder, trips: Set(gtfsTrips.map(\.id)))
        gtfsTrips = gtfsTrips.filter { (stopTimes[$0.id]?.count ?? 0) >= 2 }
        guard !gtfsTrips.isEmpty else { throw BundleError.noTrips(agency: agency) }

        let stationIDs = orderedUnique(gtfsTrips.flatMap { stopTimes[$0.id]!.map(\.stop) })
        let stops = try readStops(folder, ids: Set(stationIDs))
        let stations = try stationIDs.map { id in
            guard let stop = stops[id] else { throw BundleError.missingStation(id) }
            return stop
        }
        let stationIndex = Dictionary(uniqueKeysWithValues: stationIDs.enumerated().map { ($1, $0) })

        let shapeIDs = orderedUnique(gtfsTrips.map(\.shape))
        let rawShapes = try readShapes(folder, ids: Set(shapeIDs))
        let shapeIndex = Dictionary(uniqueKeysWithValues: shapeIDs.enumerated().map { ($1, $0) })
        var fullShapes: [(points: [Coordinate], metres: [Double])] = []
        for id in shapeIDs {
            guard let points = rawShapes[id], points.count >= 2 else { throw BundleError.missingShape(id) }
            fullShapes.append((points, Geometry.cumulativeMetres(points)))
        }

        let serviceIDs = orderedUnique(gtfsTrips.map(\.service))
        let services = try readServices(folder, ids: serviceIDs)
        let serviceIndex = Dictionary(uniqueKeysWithValues: serviceIDs.enumerated().map { ($1, $0) })

        var lines: [Line] = []
        var lineIndex: [Set<Int>: Int] = [:]
        let tripCountAt = Dictionary(gtfsTrips.flatMap { stopTimes[$0.id]!.map { (stationIndex[$0.stop]!, 1) } }, uniquingKeysWith: +)

        var trips: [Trip] = []
        for gtfs in gtfsTrips {
            let times = stopTimes[gtfs.id]!
            let shape = fullShapes[shapeIndex[gtfs.shape]!]
            var metres = 0.0
            var tripStops: [TripStop] = []
            for time in times {
                let station = stationIndex[time.stop]!
                let projection = Geometry.project(stations[station].coordinate, onto: shape.points, metres: shape.metres, from: metres)
                report.worstOffTrack = max(report.worstOffTrack, projection.offTrack)
                metres = projection.metres
                tripStops.append(TripStop(station: station, arrival: time.arrival, departure: time.departure, metres: metres))
            }
            flagFastSections(tripStops, trip: gtfs, stations: stations, report: &report)

            let ends = Set([tripStops.first!.station, tripStops.last!.station])
            let line: Int
            if let known = lineIndex[ends] {
                line = known
            } else {
                let ordered = ends.sorted { (tripCountAt[$0] ?? 0, stations[$1].name) > (tripCountAt[$1] ?? 0, stations[$0].name) }
                let names = ordered.map { stations[$0].name }
                line = lines.count
                lineIndex[ends] = line
                lines.append(Line(name: names.joined(separator: " – "), ends: ordered,
                                  international: false))
            }
            if tripStops.contains(where: { internationalStations.contains(stations[$0.station].name) }) {
                lines[line].international = true
            }
            trips.append(Trip(id: gtfs.id, code: gtfs.code, line: line, shape: shapeIndex[gtfs.shape]!,
                              service: serviceIndex[gtfs.service]!, stops: tripStops))
        }

        (lines, trips) = mergeShortTurns(lines: lines, trips: trips)

        let shapes = fullShapes.map { shape in
            Shape(points: Geometry.simplify(shape.points, tolerance: simplifyTolerance).map {
                ShapePoint(coordinate: shape.points[$0], metres: shape.metres[$0])
            })
        }
        let timetable = Timetable(feedDate: feedDate, stations: stations, lines: lines, shapes: shapes,
                                  trips: trips, services: services)
        return (timetable, report)
    }

    private struct GTFSTrip {
        let id: String
        let code: String
        let service: String
        let shape: String
    }

    private struct StopTime {
        let stop: String
        let sequence: Int
        let arrival: Int
        let departure: Int
    }

    private func readRoutes(_ folder: URL) throws -> [String: String] {
        var routes: [String: String] = [:]
        try CSVFile(url: folder.appending(path: "routes.txt")).rows { row in
            if row["agency_id"] == agency, row["route_type"] == "2" { routes[row["route_id"]] = row["route_short_name"] }
        }
        return routes
    }

    private func readTrips(_ folder: URL, routes: [String: String]) throws -> [GTFSTrip] {
        var trips: [GTFSTrip] = []
        try CSVFile(url: folder.appending(path: "trips.txt")).rows { row in
            if let code = routes[row["route_id"]] {
                trips.append(GTFSTrip(id: row["trip_id"], code: code, service: row["service_id"], shape: row["shape_id"]))
            }
        }
        return trips
    }

    private func readStopTimes(_ folder: URL, trips: Set<String>) throws -> [String: [StopTime]] {
        var times: [String: [StopTime]] = [:]
        let marker = Array("\(agency)_".utf8)
        let file = try CSVFile(url: folder.appending(path: "stop_times.txt"))
        let markedIDs = trips.allSatisfy { $0.utf8.starts(with: marker) }
        try file.rows(where: { !markedIDs || $0.contains(marker) }) { row in
            let trip = row["trip_id"]
            guard trips.contains(trip) else { return }
            let arrivalText = row["arrival_time"].isEmpty ? row["departure_time"] : row["arrival_time"]
            let departureText = row["departure_time"].isEmpty ? arrivalText : row["departure_time"]
            if arrivalText.isEmpty { return }
            let arrival = try seconds(arrivalText), departure = try seconds(departureText)
            times[trip, default: []].append(StopTime(stop: row["stop_id"], sequence: Int(row["stop_sequence"]) ?? 0,
                                                     arrival: arrival, departure: departure))
        }
        return times.mapValues { $0.sorted { $0.sequence < $1.sequence } }
    }

    private func readStops(_ folder: URL, ids: Set<String>) throws -> [String: Station] {
        var stops: [String: Station] = [:]
        try CSVFile(url: folder.appending(path: "stops.txt")).rows { row in
            let id = row["stop_id"]
            guard ids.contains(id), let latitude = Double(row["stop_lat"]), let longitude = Double(row["stop_lon"]) else { return }
            stops[id] = Station(name: row["stop_name"], coordinate: Coordinate(latitude: latitude, longitude: longitude))
        }
        return stops
    }

    private func readShapes(_ folder: URL, ids: Set<String>) throws -> [String: [Coordinate]] {
        var points: [String: [(Int, Coordinate)]] = [:]
        let shapes = try CSVFile(url: folder.appending(path: "shapes.txt"))
        let firstColumnIsID = shapes.columns["shape_id"] == 0
        let prefixes = Set(ids.map { Array("\($0),".utf8) })
        shapes.rows(where: { line in
            guard firstColumnIsID else { return true }
            guard let comma = line.firstIndex(of: 0x2C) else { return false }
            let id = line[line.startIndex...comma]
            return prefixes.contains(Array(id)) || id.first == 0x22
        }) { row in
            guard ids.contains(row["shape_id"]), let latitude = Double(row["shape_pt_lat"]), let longitude = Double(row["shape_pt_lon"]) else { return }
            points[row["shape_id"], default: []].append((Int(row["shape_pt_sequence"]) ?? 0, Coordinate(latitude: latitude, longitude: longitude)))
        }
        return points.mapValues { $0.sorted { $0.0 < $1.0 }.map(\.1) }
    }

    private func readServices(_ folder: URL, ids: [String]) throws -> [Service] {
        let wanted = Set(ids)
        var calendar: [String: Service] = [:]
        let calendarFile = folder.appending(path: "calendar.txt"), datesFile = folder.appending(path: "calendar_dates.txt")
        let hasCalendar = FileManager.default.fileExists(atPath: calendarFile.path)
        let hasDates = FileManager.default.fileExists(atPath: datesFile.path)
        guard hasCalendar || hasDates else { throw BundleError.noCalendar }
        if hasCalendar { try CSVFile(url: calendarFile).rows { row in
            let id = row["service_id"]
            guard wanted.contains(id) else { return }
            let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"].map { row[$0] }.joined()
            calendar[id] = Service(weekdays: days, start: Int(row["start_date"]) ?? 0, end: Int(row["end_date"]) ?? 0,
                                   added: [], removed: [])
        } }
        if hasDates { try CSVFile(url: datesFile).rows { row in
            let id = row["service_id"]
            guard wanted.contains(id), let date = Int(row["date"]) else { return }
            var service = calendar[id] ?? Service(weekdays: "0000000", start: 0, end: 0, added: [], removed: [])
            if row["exception_type"] == "1" { service.added.append(date) } else { service.removed.append(date) }
            calendar[id] = service
        } }
        return ids.map { id in
            var service = calendar[id] ?? Service(weekdays: "0000000", start: 0, end: 0, added: [], removed: [])
            service.added.sort()
            service.removed.sort()
            return service
        }
    }

    private func mergeShortTurns(lines: [Line], trips: [Trip]) -> ([Line], [Trip]) {
        let paths = trips.map { Set($0.stops.map(\.station)) }
        let span = Dictionary(trips.map { ($0.line, $0.stops.count) }, uniquingKeysWith: max)
        let count = Dictionary(trips.map { ($0.line, 1) }, uniquingKeysWith: +)
        var target = Array(lines.indices)
        for (index, line) in lines.enumerated() {
            let covering = trips.indices
                .filter { trips[$0].line != index && paths[$0].isSuperset(of: line.ends) }
                .map { trips[$0].line }
            if let longest = covering.max(by: { (span[$0] ?? 0, $1) < (span[$1] ?? 0, $0) }),
               (span[longest] ?? 0) > (span[index] ?? 0),
               (count[index] ?? 0) <= 2 * (count[longest] ?? 0) {
                target[index] = longest
            }
        }
        func root(_ line: Int) -> Int {
            var line = line, steps = 0
            while target[line] != line, steps < lines.count { line = target[line]; steps += 1 }
            return line
        }
        let kept = lines.indices.filter { root($0) == $0 }
        let newIndex = Dictionary(uniqueKeysWithValues: kept.enumerated().map { ($1, $0) })
        var merged = kept.map { lines[$0] }
        var moved = trips
        for index in moved.indices {
            let line = newIndex[root(moved[index].line)]!
            if lines[moved[index].line].international { merged[line].international = true }
            moved[index].line = line
        }
        return (merged, moved)
    }

    private func flagFastSections(_ stops: [TripStop], trip: GTFSTrip, stations: [Station], report: inout BundleReport) {
        for (a, b) in zip(stops, stops.dropFirst()) {
            let time = Double(b.arrival - a.departure), distance = b.metres - a.metres
            if time > 0, distance / time > fastSectionSpeed {
                report.fastSections.append(
                    "\(trip.code) \(stations[a.station].name) → \(stations[b.station].name): " +
                    "\(Int((distance / 1000).rounded())) km in \(Int(time / 60)) min")
            }
        }
    }

    private func seconds(_ text: String) throws -> Int {
        let pieces = text.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        let parts = pieces.compactMap { Int($0) }
        guard pieces.count == 3, parts.count == 3, parts[1] < 60, parts[2] < 60 else { throw BundleError.badTime(text) }
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }

    private func orderedUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        return values.filter { seen.insert($0).inserted }
    }
}
