import SwiftUI

struct StationMarker: View {
    let name: String
    let station: Int
    let chosen: Bool
    var compact = false
    /// True while a train stands at the station at country zoom: the station's tap area is
    /// then its ring alone, so a tap on the train around it is the train's.
    var underTrain = false
    let open: MapOpener

    var body: some View {
        Button {
            open(.station(station))
        } label: {
            Circle()
                .fill(.background)
                .stroke(.primary, lineWidth: chosen ? 3 : 2)
                .frame(width: chosen ? 14 : 10, height: chosen ? 14 : 10)
                // The ring looks the same at each zoom; at country zoom its tap area is the
                // full 44 points, unless a train stands there. MapKit gives a touch to the
                // annotation whose frame holds it, even one that takes no taps, so the frame
                // itself shrinks to the ring.
                .frame(width: tapSize, height: tapSize)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityHint(Text(.boardStationHint))
        .accessibilityIdentifier(A11yID.Map.station)
    }

    private var tapSize: CGFloat {
        if underTrain { chosen ? 14 : 10 } else if compact { 44 } else { 30 }
    }
}
