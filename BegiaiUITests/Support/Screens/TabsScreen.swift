import XCTest

@MainActor
struct TabsScreen {
    let journey: JourneyApp

    func expectMapSelected(file: StaticString = #filePath, line: UInt = #line) {
        let map = journey.wait(for: journey.app.tabBars.buttons.firstMatch, "the first tab", on: "Tabs",
                               file: file, line: line)
        XCTAssertTrue(map.isSelected, "Tabs: the first tab is not the selected tab", file: file, line: line)
        journey.wait(for: journey.element(A11yID.Map.page), "the Map page", on: "Tabs", file: file, line: line)
    }
}
