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

    @Test func aSealedLaunchCanLoadItsOwnTimetable() throws {
        let launch = try SealedLaunch.read(arguments: ["Begiai", "--sealed", "--timetable", "/tmp/frozen.json"], allowed: true)
        #expect(launch?.timetable == URL(filePath: "/tmp/frozen.json"))
        #expect(throws: SealedLaunch.Failure.noTimetable("frozen.json")) {
            try SealedLaunch.read(arguments: ["Begiai", "--sealed", "--timetable", "frozen.json"], allowed: true)
        }
    }

    @Test func aSealedLaunchCanRunItsClockFasterForARecording() throws {
        let launch = try SealedLaunch.read(arguments: ["Begiai", "--sealed", "--now", SealedWorld.now, "--speed", "60"], allowed: true)
        #expect(launch?.speed == 60)
        #expect(throws: SealedLaunch.Failure.badSpeed("fast")) {
            try SealedLaunch.read(arguments: ["Begiai", "--sealed", "--speed", "fast"], allowed: true)
        }
        #expect(throws: SealedLaunch.Failure.badSpeed("0")) {
            try SealedLaunch.read(arguments: ["Begiai", "--sealed", "--speed", "0"], allowed: true)
        }
    }

    @Test func aFastClockStartsAtItsTimeAndRunsAtItsSpeed() {
        let start = Date(timeIntervalSince1970: 1_794_930_900)
        let began = Date(timeIntervalSince1970: 1_000)
        let clock = FastClock(start: start, speed: 60, began: began)
        #expect(clock.time(at: began) == start)
        #expect(clock.time(at: began.addingTimeInterval(10)) == start.addingTimeInterval(600))
        #expect(!clock.isPinned)
    }
}
