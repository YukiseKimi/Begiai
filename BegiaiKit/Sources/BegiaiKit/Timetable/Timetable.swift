import Foundation

public struct Timetable: Codable, Sendable, Equatable {
    public var feedDate: Int
    public var stations: [Station]
    public var lines: [Line]
    public var shapes: [Shape]
    public var trips: [Trip]
    public var services: [Service]

    public init(feedDate: Int, stations: [Station], lines: [Line], shapes: [Shape], trips: [Trip], services: [Service]) {
        self.feedDate = feedDate
        self.stations = stations
        self.lines = lines
        self.shapes = shapes
        self.trips = trips
        self.services = services
    }
}

public struct Coordinate: Codable, Sendable, Equatable, Hashable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        latitude = Double(try values.decode(Int.self)) / 1_000_000
        longitude = Double(try values.decode(Int.self)) / 1_000_000
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.unkeyedContainer()
        try values.encode(Int((latitude * 1_000_000).rounded()))
        try values.encode(Int((longitude * 1_000_000).rounded()))
    }
}

public struct Station: Codable, Sendable, Equatable {
    public var name: String
    public var coordinate: Coordinate

    public init(name: String, coordinate: Coordinate) {
        self.name = name
        self.coordinate = coordinate
    }
}

public struct Line: Codable, Sendable, Equatable {
    public var name: String
    public var ends: [Int]
    public var international: Bool

    public init(name: String, ends: [Int], international: Bool) {
        self.name = name
        self.ends = ends
        self.international = international
    }
}

public struct ShapePoint: Codable, Sendable, Equatable {
    public var coordinate: Coordinate
    public var metres: Double

    public init(coordinate: Coordinate, metres: Double) {
        self.coordinate = coordinate
        self.metres = metres
    }

    public init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        let latitude = Double(try values.decode(Int.self)) / 1_000_000
        let longitude = Double(try values.decode(Int.self)) / 1_000_000
        coordinate = Coordinate(latitude: latitude, longitude: longitude)
        metres = Double(try values.decode(Int.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.unkeyedContainer()
        try values.encode(Int((coordinate.latitude * 1_000_000).rounded()))
        try values.encode(Int((coordinate.longitude * 1_000_000).rounded()))
        try values.encode(Int(metres.rounded()))
    }
}

public struct Shape: Codable, Sendable, Equatable {
    public var points: [ShapePoint]

    public init(points: [ShapePoint]) {
        self.points = points
    }

    public var length: Double { points.last?.metres ?? 0 }
}

public struct Trip: Codable, Sendable, Equatable {
    public var id: String
    public var code: String
    public var line: Int
    public var shape: Int
    public var service: Int
    public var stops: [TripStop]

    public init(id: String, code: String, line: Int, shape: Int, service: Int, stops: [TripStop]) {
        self.id = id
        self.code = code
        self.line = line
        self.shape = shape
        self.service = service
        self.stops = stops
    }
}

public struct TripStop: Codable, Sendable, Equatable {
    public var station: Int
    public var arrival: Int
    public var departure: Int
    public var metres: Double

    public init(station: Int, arrival: Int, departure: Int, metres: Double) {
        self.station = station
        self.arrival = arrival
        self.departure = departure
        self.metres = metres
    }

    public init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        station = try values.decode(Int.self)
        arrival = try values.decode(Int.self)
        departure = try values.decode(Int.self)
        metres = Double(try values.decode(Int.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.unkeyedContainer()
        try values.encode(station)
        try values.encode(arrival)
        try values.encode(departure)
        try values.encode(Int(metres.rounded()))
    }
}

public struct Service: Codable, Sendable, Equatable {
    public var weekdays: String
    public var start: Int
    public var end: Int
    public var added: [Int]
    public var removed: [Int]

    public init(weekdays: String, start: Int, end: Int, added: [Int], removed: [Int]) {
        self.weekdays = weekdays
        self.start = start
        self.end = end
        self.added = added
        self.removed = removed
    }
}
