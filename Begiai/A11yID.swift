enum A11yID {
    enum Map {
        static let page = "map.page"
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
        Entry(id: LineDiagram.page, element: "the Line Diagram tab's content", screen: "Line Diagram"),
    ]
}
