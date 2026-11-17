enum A11yID {
    enum Map {
        static let page = "map.page"
        static let runningCount = "map.runningCount"
        static let train = "map.train"
        static let panel = "map.panel"
        static let lineRow = "map.lineRow"
        static let filter = "map.filter"
    }

    enum LineDiagram {
        static let page = "lineDiagram.page"
    }

    struct Entry {
        let id: String
        let element: String
        let screen: String
    }

    static let entries: [Entry] = [
        Entry(id: Map.page, element: "the Map tab's content", screen: "Map"),
        Entry(id: Map.runningCount, element: "the count of trains running now", screen: "Map"),
        Entry(id: Map.train, element: "each train on the map", screen: "Map"),
        Entry(id: Map.panel, element: "the handle of the line panel", screen: "Map"),
        Entry(id: Map.lineRow, element: "each line row in the panel", screen: "Map"),
        Entry(id: Map.filter, element: "the All, Starred and International filter", screen: "Map"),
        Entry(id: LineDiagram.page, element: "the Line Diagram tab's content", screen: "Line Diagram"),
    ]
}
