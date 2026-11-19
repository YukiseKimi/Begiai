import BegiaiKit
import BegiaiKitTestSupport
import Foundation
import Testing

@Suite("Sealed launch", .timeLimit(.minutes(1)))
struct SealedLaunchTests {
    @Test func aBuildThatDoesNotAllowItIgnoresEveryFlag() throws {
        let launch = try SealedLaunch.read(arguments: ["Begiai", "--sealed", "--now", "2026-11-17T15:55:00Z"], allowed: false)
        #expect(launch == nil)
    }

    @Test func theSealedLaunchPinsTheClock() throws {
        let launch = try SealedLaunch.read(arguments: ["Begiai", "--sealed", "--reset", "--now", SealedWorld.now], allowed: true)
        #expect(launch == SealedLaunch(now: Date(timeIntervalSince1970: 1_794_930_900), reset: true))
    }

    @Test func aMisspeltFlagStopsTheLaunch() {
        #expect(throws: SealedLaunch.Failure.unknownFlag("--rest")) {
            try SealedLaunch.read(arguments: ["Begiai", "--sealed", "--rest"], allowed: true)
        }
    }

    @Test func aSealedLaunchShowsTheWelcomeOnlyWhenAsked() throws {
        let plain = try SealedLaunch.read(arguments: ["Begiai", "--sealed"], allowed: true)
        let welcome = try SealedLaunch.read(arguments: ["Begiai", "--sealed", "--welcome"], allowed: true)
        #expect(plain?.welcome == false)
        #expect(welcome?.welcome == true)
    }
}
