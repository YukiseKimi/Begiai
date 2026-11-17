import SwiftUI

struct StationMarker: View {
    let name: String
    let chosen: Bool
    var compact = false
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            Circle()
                .fill(.background)
                .stroke(.primary, lineWidth: chosen ? 3 : 2)
                .frame(width: chosen ? 14 : 10, height: chosen ? 14 : 10)
                .frame(width: compact ? 14 : 30, height: compact ? 14 : 30)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityHint(Text(.boardStationHint))
        .accessibilityIdentifier(A11yID.Map.station)
    }
}
