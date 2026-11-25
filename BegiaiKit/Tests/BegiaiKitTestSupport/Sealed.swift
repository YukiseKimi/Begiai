import BegiaiKit
import Foundation
import Testing

public enum SealedWorld {
    /// The time that the journeys pin: 15:55 UTC, the evening peak at 17:55 in Vilnius.
    public static let now = "2026-11-17T15:55:00Z"
    public static let day = try! Date(now, strategy: .iso8601)
}

/// The world of one sealed test: a temporary folder of its own.
public struct TestWorld: Sendable {
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
        try await TestWorld.$current.withValue(TestWorld(folder: folder)) {
            try await function()
        }
    }
}

extension Trait where Self == SealedTrait {
    public static var sealed: SealedTrait { SealedTrait() }
}
