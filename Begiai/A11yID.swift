enum A11yID {
    enum Map {
        static let page = "map.page"
        static let runningCount = "map.runningCount"
        static let train = "map.train"
        static let panel = "map.panel"
        static let lineName = "map.lineName"
        static let lineStar = "map.lineStar"
        static let filter = "map.filter"
    }

    enum Train {
        static let title = "train.title"
        static let back = "train.back"
        static let follow = "train.follow"
        static let stop = "train.stop"
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
        Entry(id: Map.lineName, element: "the name and train count of each line row", screen: "Map"),
        Entry(id: Map.lineStar, element: "the star button in each line row", screen: "Map"),
        Entry(id: Map.filter, element: "the All, Starred and International filter", screen: "Map"),
        Entry(id: Train.title, element: "the title of a train's page", screen: "Train"),
        Entry(id: Train.back, element: "the Lines button on a train's page", screen: "Train"),
        Entry(id: Train.follow, element: "the Follow button on a train's page", screen: "Train"),
        Entry(id: Train.stop, element: "each stop in a train's stop list", screen: "Train"),
        Entry(id: LineDiagram.page, element: "the Line Diagram tab's content", screen: "Line Diagram"),
    ]
}
