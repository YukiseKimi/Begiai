import Foundation
import SwiftData

@Model
public final class Star {
    #Unique<Star>([\.kind, \.name])

    public var kind: String
    public var name: String
    public var addedAt: Date

    public init(kind: StarKind, name: String, addedAt: Date) {
        self.kind = kind.rawValue
        self.name = name
        self.addedAt = addedAt
    }
}

public enum StarKind: String, Sendable {
    case line
    case station
}

extension ModelContext {
    public func starredNames(_ kind: StarKind) throws -> Set<String> {
        let raw = kind.rawValue
        return Set(try fetch(FetchDescriptor<Star>(predicate: #Predicate { $0.kind == raw })).map(\.name))
    }

    public func toggleStar(_ kind: StarKind, name: String, at date: Date) throws {
        let raw = kind.rawValue
        let existing = try fetch(FetchDescriptor<Star>(predicate: #Predicate { $0.kind == raw && $0.name == name }))
        if existing.isEmpty {
            insert(Star(kind: kind, name: name, addedAt: date))
        } else {
            existing.forEach(delete)
        }
        try save()
    }
}

public enum StarStorage {
    public static func container(sealedFolder: URL?) throws -> ModelContainer {
        let schema = Schema([Star.self])
        if let sealedFolder {
            try FileManager.default.createDirectory(at: sealedFolder, withIntermediateDirectories: true)
            return try ModelContainer(for: schema, configurations: ModelConfiguration(url: sealedFolder.appending(path: "Begiai.store")))
        }
        return try ModelContainer(for: schema)
    }
}
