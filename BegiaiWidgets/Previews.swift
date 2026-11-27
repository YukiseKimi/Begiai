import BegiaiKit
import SwiftUI
import WidgetKit

extension FollowedTrain {
    /// Vilnius → Kaunas through Lentvaris, Vievis and Kaišiadorys, an hour from Kaunas.
    static var preview: FollowedTrain { vilniusKaunas(out: 22) }

    /// The same train 34 minutes from Kaunas, a trip under an hour.
    static var nearlyThere: FollowedTrain { vilniusKaunas(out: 48) }

    /// Vilnius → Kaunas, `minutes` out of Vilnius: the whole trip takes 82 minutes.
    static func vilniusKaunas(out minutes: Double) -> FollowedTrain {
        let start = Date.now.addingTimeInterval(-minutes * 60)
        func at(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60) }
        return FollowedTrain(
            trip: "preview", day: ServiceDate(.now).number, line: "Vilnius – Kaunas", colour: 4,
            stops: [
                Stop(name: "Vilnius", arrival: at(0), departure: at(0)),
                Stop(name: "Lentvaris", arrival: at(12), departure: at(13)),
                Stop(name: "Vievis", arrival: at(29), departure: at(30)),
                Stop(name: "Kaišiadorys", arrival: at(48), departure: at(50)),
                Stop(name: "Kaunas", arrival: at(82), departure: at(82)),
            ])
    }
}

extension FollowedTrain {
    /// The longest names in the timetable, to check that each line ends in “…” and not at the
    /// edge, on a trip of over three hours.
    static var longNames: FollowedTrain {
        let start = Date.now.addingTimeInterval(-40 * 60)
        func at(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60) }
        return FollowedTrain(
            trip: "preview-long", day: ServiceDate(.now).number, line: "Vilnius – Rīgas Centrālā stacija", colour: 1,
            stops: [
                Stop(name: "Elektrinių traukinių depas-1", arrival: at(0), departure: at(0)),
                Stop(name: "Švenčionėliai", arrival: at(55), departure: at(57)),
                Stop(name: "Rīgas Centrālā stacija", arrival: at(240), departure: at(240)),
            ])
    }
}

extension FollowedTrain.Status {
    static let running = FollowedTrain.Status(place: .leaving(1))
    static let standing = FollowedTrain.Status(place: .at(3))
    static let arrived = FollowedTrain.Status(place: .arrived)
}

#Preview("Lock Screen", as: .content, using: FollowedTrain.preview) {
    FollowedTrainActivity()
} contentStates: {
    FollowedTrain.Status.running
    FollowedTrain.Status.standing
    FollowedTrain.Status.arrived
}

#Preview("Compact", as: .dynamicIsland(.compact), using: FollowedTrain.preview) {
    FollowedTrainActivity()
} contentStates: {
    FollowedTrain.Status.running
    FollowedTrain.Status.arrived
}

#Preview("Compact, under an hour", as: .dynamicIsland(.compact), using: FollowedTrain.nearlyThere) {
    FollowedTrainActivity()
} contentStates: {
    FollowedTrain.Status.standing
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: FollowedTrain.preview) {
    FollowedTrainActivity()
} contentStates: {
    FollowedTrain.Status.running
    FollowedTrain.Status.standing
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: FollowedTrain.preview) {
    FollowedTrainActivity()
} contentStates: {
    FollowedTrain.Status.running
}

#Preview("Lock Screen, long names", as: .content, using: FollowedTrain.longNames) {
    FollowedTrainActivity()
} contentStates: {
    FollowedTrain.Status(place: .leaving(0))
}

#Preview("Expanded, long names", as: .dynamicIsland(.expanded), using: FollowedTrain.longNames) {
    FollowedTrainActivity()
} contentStates: {
    FollowedTrain.Status(place: .leaving(0))
}

#Preview("Compact, long names", as: .dynamicIsland(.compact), using: FollowedTrain.longNames) {
    FollowedTrainActivity()
} contentStates: {
    FollowedTrain.Status(place: .leaving(0))
    // Once in, the arrival time stays whole and the long name gives way.
    FollowedTrain.Status.arrived
}
