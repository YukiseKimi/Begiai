import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import SwiftData
import Testing

@MainActor
@Suite("Stars", .sealed, .timeLimit(.minutes(1)))
struct StarTests {
    @Test func aStarStaysAfterTheStoreOpensAgain() throws {
        let folder = try #require(TestWorld.current).folder
        do {
            let container = try StarStorage.container(sealedFolder: folder)
            try container.mainContext.toggleStar(.line, name: "Vilnius – Kaunas", at: SealedWorld.day)
        }
        let reopened = try StarStorage.container(sealedFolder: folder)
        #expect(try reopened.mainContext.starredNames(.line) == ["Vilnius – Kaunas"])
    }

    @Test func aSecondTapTakesTheStarAway() throws {
        let container = try StarStorage.container(sealedFolder: try #require(TestWorld.current).folder)
        let context = container.mainContext
        try context.toggleStar(.line, name: "Vilnius – Kaunas", at: SealedWorld.day)
        try context.toggleStar(.line, name: "Vilnius – Kaunas", at: SealedWorld.day)
        #expect(try context.starredNames(.line).isEmpty)
    }

    @Test func aStationStarIsNotALineStar() throws {
        let container = try StarStorage.container(sealedFolder: try #require(TestWorld.current).folder)
        let context = container.mainContext
        try context.toggleStar(.station, name: "Kaunas", at: SealedWorld.day)
        #expect(try context.starredNames(.line).isEmpty)
        #expect(try context.starredNames(.station) == ["Kaunas"])
    }
}
