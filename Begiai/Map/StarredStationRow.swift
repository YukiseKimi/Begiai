import BegiaiKit
import SwiftUI

/// A starred station that the timetable has, with its next train, as its row shows it.
struct StarredStation: Identifiable {
    let index: Int
    let name: String
    let next: Departure?
    /// The minutes from now to the next train.
    let minutes: Int?

    var id: Int { index }

    /// The starred stations that the timetable has, by name, each with its next train at `now`.
    static func all(_ names: Set<String>, engine: MotionEngine, now: Date) -> [StarredStation] {
        names.sorted().compactMap { name in
            engine.stationNames.firstIndex(of: name).map { index in
                let next = engine.departures(from: index, at: now, limit: 1).first
                return StarredStation(index: index, name: name, next: next, minutes: next?.time.minutes(after: now))
            }
        }
    }
}

/// One starred station at the top of the line list, with its next train: the glance that a
/// station widget gives in Eki Bright, without leaving the map. A tap opens the station's board.
struct StarredStationRow: View {
    let station: StarredStation
    @Binding var selection: PageSelection?

    var body: some View {
        Button {
            selection = .station(station.index)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: station.name)
                        .font(.body.weight(.medium))
                    if let next = station.next {
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
                if let minutes = station.minutes, minutes <= 60 {
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
        StarredStationRow(station: StarredStation(index: 0, name: "Kaunas", next: nil, minutes: nil), selection: .constant(nil))
    }
}
