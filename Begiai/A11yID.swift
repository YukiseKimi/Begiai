enum A11yID {
    enum Map {
        static let page = "map.page"
        static let runningCount = "map.runningCount"
        static let train = "map.train"
        static let panel = "map.panel"
        static let lineName = "map.lineName"
        static let lineStar = "map.lineStar"
        static let filter = "map.filter"
        static let station = "map.station"
        static let firstTrain = "map.firstTrain"
        static let locate = "map.locate"
    }

    enum Train {
        static let title = "train.title"
        static let back = "train.back"
        static let follow = "train.follow"
        static let stop = "train.stop"
    }

    enum Board {
        static let title = "board.title"
        static let back = "board.back"
        static let row = "board.row"
        static let star = "board.star"
    }

    enum LineDiagram {
        static let page = "lineDiagram.page"
        static let chip = "lineDiagram.chip"
        static let frequency = "lineDiagram.frequency"
        static let station = "lineDiagram.station"
        static let train = "lineDiagram.train"
    }

    enum Timetable {
        static let stale = "timetable.stale"
    }

    enum Welcome {
        static let title = "welcome.title"
        static let next = "welcome.next"
    }

    enum About {
        static let open = "about.open"
        static let close = "about.close"
        static let timetableDate = "about.timetableDate"
        static let source = "about.source"
        static let unofficial = "about.unofficial"
        static let tipThanks = "about.tipThanks"
        static let largerMarkers = "about.largerMarkers"
        static let highContrast = "about.highContrast"
    }

    enum Notices {
        static let link = "notices.link"
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
        Entry(id: Map.locate, element: "the Locate button on the map", screen: "Map"),
        Entry(id: Map.firstTrain, element: "the first train on the night card", screen: "Map"),
        Entry(id: Map.station, element: "each station marker on the map", screen: "Map"),
        Entry(id: Board.title, element: "the station name on its board", screen: "Board"),
        Entry(id: Board.back, element: "the Lines button on a station board", screen: "Board"),
        Entry(id: Board.row, element: "each departure on a station board", screen: "Board"),
        Entry(id: Board.star, element: "the star button of a station board", screen: "Board"),
        Entry(id: LineDiagram.page, element: "the name of the line on the Line Diagram tab", screen: "Line Diagram"),
        Entry(id: LineDiagram.chip, element: "each line chip at the top of the Line Diagram", screen: "Line Diagram"),
        Entry(id: LineDiagram.frequency, element: "how often the trains of the chosen line leave", screen: "Line Diagram"),
        Entry(id: LineDiagram.station, element: "each station on the line diagram", screen: "Line Diagram"),
        Entry(id: LineDiagram.train, element: "each train on the line diagram", screen: "Line Diagram"),
        Entry(id: Welcome.title, element: "the title of the welcome card that shows", screen: "Welcome"),
        Entry(id: Welcome.next, element: "the Next or Start button of the welcome sheet", screen: "Welcome"),
        Entry(id: About.open, element: "the ⓘ button on the map", screen: "Map"),
        Entry(id: About.close, element: "the close button of About", screen: "About"),
        Entry(id: About.timetableDate, element: "the date of the timetable in use", screen: "About"),
        Entry(id: About.source, element: "the link to the timetable source", screen: "About"),
        Entry(id: About.unofficial, element: "the note that the app is not from LTG", screen: "About"),
        Entry(id: About.largerMarkers, element: "the Larger markers toggle", screen: "About"),
        Entry(id: About.highContrast, element: "the High contrast toggle", screen: "About"),
        Entry(id: About.tipThanks, element: "the thank-you, or the waiting or failed note, after a tip", screen: "About"),
        Entry(id: Notices.link, element: "the link to LTG Link's notices", screen: "Line Diagram, Train"),
        Entry(id: Timetable.stale, element: "the note that the timetable is old", screen: "Map, Line Diagram"),
    ]
}
