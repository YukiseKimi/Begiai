import BegiaiKit
import BegiaiKitTestSupport
import Testing

@Suite("Station search", .sealed, .timeLimit(.minutes(1)))
struct StationSearchTests {
    let names = ["Vilnius", "Kaišiadorys", "Kaunas", "Lentvaris", "Šiauliai", "Pabradė"]

    @Test func aQueryWithoutLithuanianLettersFindsTheStation() {
        #expect(StationSearch.matches("kaisiadorys", in: names) == [1])
        #expect(StationSearch.matches("SIAUL", in: names) == [4])
        #expect(StationSearch.matches("pabrade", in: names) == [5])
    }

    @Test func namesThatStartWithTheQueryComeFirstThenTheOthersByName() {
        #expect(StationSearch.matches("ka", in: names) == [1, 2])
        // “ai” starts no name; it is inside Kaišiadorys and Šiauliai.
        #expect(StationSearch.matches("ai", in: names) == [1, 4])
        #expect(StationSearch.matches("s", in: names) == [4, 1, 2, 3, 0])
    }

    @Test func theBusierStationComesFirstWithinEachGroup() {
        let names = ["Vilkaviškis", "Vilkyčiai", "Vilnius", "Kaunas", "Pakaunė"]
        let calls = [12, 4, 240, 180, 300]
        #expect(StationSearch.matches("vil", in: names, calls: calls) == [2, 0, 1])
        // Pakaunė is the busiest, but its name does not start with “kau”.
        #expect(StationSearch.matches("kau", in: names, calls: calls) == [3, 4])
    }

    @Test func anEmptyQueryFindsNothing() {
        #expect(StationSearch.matches("", in: names).isEmpty)
        #expect(StationSearch.matches("   ", in: names).isEmpty)
    }
}
