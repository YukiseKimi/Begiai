import BegiaiKit
import SwiftUI

/// One starred station at the top of the line list, with its next train: the glance that a
/// station widget gives in Eki Bright, without leaving the map. A tap opens the station's board.
struct StarredStationRow: View {
    let name: String
    let next: Departure?
    let now: Date
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: name)
                        .font(.body.weight(.medium))
                    if let next {
                        Text(.stationNext(time: next.time.vilniusTime, destination: next.destination))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    } else {
                        Text(.boardNone)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let next, case let minutes = next.time.minutes(after: now), minutes <= 60 {
                    Text(minutes == 0 ? .boardNow : .trainIn(minutes: minutes))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(.boardStationHint))
        .accessibilityIdentifier(A11yID.Map.starredStation)
    }
}

#Preview {
    List {
        StarredStationRow(name: "Kaunas", next: nil, now: .now) {}
    }
}
