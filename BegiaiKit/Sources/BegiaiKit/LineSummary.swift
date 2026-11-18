import Foundation

public struct LineSummary: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let international: Bool
    public let trainsNow: Int
    public let tripsToday: Int

    public init(id: Int, name: String, international: Bool, trainsNow: Int, tripsToday: Int) {
        self.id = id
        self.name = name
        self.international = international
        self.trainsNow = trainsNow
        self.tripsToday = tripsToday
    }
}

extension MotionEngine {
    public func lineSummaries(at date: Date, trains: [TrainState], starred: Set<String> = []) -> [LineSummary] {
        let lines = timetable.lines
        var now = Array(repeating: 0, count: lines.count)
        for train in trains where now.indices.contains(timetable.trips[train.trip].line) { now[timetable.trips[train.trip].line] += 1 }
        let today = day(ServiceDate(date)).tripsPerLine
        return lines.indices
            .map {
                LineSummary(id: $0, name: lines[$0].name, international: lines[$0].international, trainsNow: now[$0], tripsToday: today[$0])
            }
            .sorted { a, b in
                let (aStar, bStar) = (starred.contains(a.name), starred.contains(b.name))
                if aStar != bStar { return aStar }
                if a.tripsToday != b.tripsToday { return a.tripsToday > b.tripsToday }
                return a.name < b.name
            }
    }
}

public enum LineFilter: CaseIterable, Hashable, Sendable {
    case all
    case starred
    case international

    public func includes(_ line: LineSummary, starred: Set<String>) -> Bool {
        switch self {
        case .all: true
        case .starred: starred.contains(line.name)
        case .international: line.international
        }
    }
}
