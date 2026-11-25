import BegiaiKit
import SwiftUI
import WidgetKit

extension FollowedTrain {
    /// Vilnius → Kaunas through Lentvaris, Vievis and Kaišiadorys, 22 minutes out of Vilnius.
    static var preview: FollowedTrain {
        let start = Date.now.addingTimeInterval(-22 * 60)
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
