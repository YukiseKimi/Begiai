import Foundation

/// Gets a newer timetable from GitHub Pages at most one time each day, and keeps it in a
/// folder of its own. Each step that fails keeps the copy that the app has.
public struct TimetableFeed: Sendable {
    public typealias Fetch = @Sendable (URL) async throws -> Data

    public enum Outcome: Equatable, Sendable {
        /// The last check was less than a day ago.
        case tooSoon
        /// The feed has no newer timetable of a format that this app reads.
        case upToDate
        /// A newer timetable is saved. The store adopts it at the next launch, or when the app
        /// comes back to the front with no train or station open.
        case saved(feedDate: Int)
        case failed(String)
    }

    public static let pages = URL(string: "https://yukisekimi.github.io/Begiai/")!

    private let base: URL
    private let folder: URL
    private let fetch: Fetch

    public init(base: URL = pages, folder: URL, fetch: @escaping Fetch = TimetableFeed.download) {
        self.base = base
        self.folder = folder
        self.fetch = fetch
    }

    /// The timetables to try at launch, best first: the saved one only when it is newer than
    /// the one that the app ships.
    @concurrent
    public func candidates(bundled: URL) async -> [URL] {
        guard let saved = Self.feedDate(of: savedTimetable), let shipped = Self.feedDate(of: bundled), saved > shipped
        else { return [bundled] }
        return [savedTimetable, bundled]
    }

    /// The saved timetable, if its feed date is later than `loaded`.
    @concurrent
    func pending(newerThan loaded: Int) async -> URL? {
        guard let saved = Self.feedDate(of: savedTimetable), saved > loaded else { return nil }
        return savedTimetable
    }

    /// Saves a newer timetable than `loaded` if the feed has one. A network error does not
    /// count as a check, so the next launch tries again. A saved copy that failed to load is
    /// not `loaded`, so the feed replaces it.
    @concurrent
    public func refresh(now: Date, loaded: Int) async -> Outcome {
        if let last = lastCheck, now.timeIntervalSince(last) < 24 * 3600, now >= last { return .tooSoon }
        let manifestData: Data
        do {
            manifestData = try await fetch(base.appending(path: "manifest.json"))
        } catch {
            return .failed("no manifest: \(error)")
        }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
            guard manifest.format == Timetable.format, manifest.feedDate > loaded else {
                record(check: now)
                return .upToDate
            }
            let data: Data
            do {
                data = try await fetch(base.appending(path: "timetable.json"))
            } catch {
                return .failed("no bundle: \(error)")
            }
            record(check: now)
            guard manifest.names(data) else { return .failed("the bundle is not the one that the manifest names") }
            let timetable = try JSONDecoder().decode(Timetable.self, from: data)
            try timetable.check()
            guard timetable.feedDate == manifest.feedDate else { return .failed("the bundle has another feed date") }
            try FileManager.default.createDirectory(at: savedTimetable.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: savedTimetable, options: .atomic)
            return .saved(feedDate: timetable.feedDate)
        } catch {
            return .failed(String(describing: error))
        }
    }

    public static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    /// One folder for each format, so that an app that reads a new format never tries a copy
    /// of the old one.
    private var savedTimetable: URL { folder.appending(path: "format-\(Timetable.format)/timetable.json") }
    private var checkFile: URL { folder.appending(path: "checked-at") }

    private var lastCheck: Date? {
        guard let text = try? String(contentsOf: checkFile, encoding: .utf8) else { return nil }
        return try? Date(text, strategy: .iso8601)
    }

    private func record(check now: Date) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Data(now.ISO8601Format().utf8).write(to: checkFile, options: .atomic)
    }

    private struct Head: Decodable {
        let feedDate: Int
    }

    /// The feed date of a timetable file, or nil if there is no readable file.
    static func feedDate(of url: URL) -> Int? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Head.self, from: data).feedDate
    }
}
