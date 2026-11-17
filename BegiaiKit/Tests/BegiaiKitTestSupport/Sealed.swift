import BegiaiKit
import Foundation
import Testing

public enum SealedWorld {
    public static let day: Date = {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 11; parts.day = 17
        parts.hour = 17; parts.minute = 55
        return Vilnius.calendar.date(from: parts)!
    }()
}

public final class PinnedTime: TimeSource, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    public init(_ start: Date = SealedWorld.day) { current = start }

    public var now: Date { lock.withLock { current } }

    public func advance(by seconds: TimeInterval) { lock.withLock { current += seconds } }
}

public struct TestWorld: Sendable {
    public let time: PinnedTime
    public let folder: URL

    @TaskLocal public static var current: TestWorld?
}

public struct SealedTrait: TestTrait, SuiteTrait, TestScoping {
    public var isRecursive: Bool { true }

    public func provideScope(
        for test: Test, testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        guard testCase != nil || !test.isSuite else { return try await function() }
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "BegiaiKitTests.\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try await TestWorld.$current.withValue(TestWorld(time: PinnedTime(), folder: folder)) {
            try await function()
        }
    }
}

extension Trait where Self == SealedTrait {
    public static var sealed: SealedTrait { SealedTrait() }
}

public func eventually(
    _ what: String,
    timeout: Duration = .seconds(5),
    isolation: isolated (any Actor)? = #isolation,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: () async throws -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while try await !condition() {
        let inTime = ContinuousClock.now < deadline
        try #require(inTime, "waited \(timeout) for \(what)", sourceLocation: sourceLocation)
        try await Task.sleep(for: .milliseconds(10))
    }
}
