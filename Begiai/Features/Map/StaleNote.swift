import BegiaiKit
import SwiftUI

/// Says the date of the timetable when it is old, so that nobody trusts it too much. Give it
/// `Timetable.staleSince(on:)`: it shows nothing for nil, and its body runs again only when
/// the day changes.
struct StaleNote: View {
    let since: ServiceDate?

    var body: some View {
        if let since {
            Label {
                Text(
                    .timetableStale(
                        date: since.midnight.formatted(
                            Date.FormatStyle(timeZone: Vilnius.timeZone).day().month(.abbreviated))))
            } icon: {
                Image(systemName: "clock.badge.exclamationmark")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(A11yID.Timetable.stale)
        }
    }
}

#Preview {
    StaleNote(since: ServiceDate(year: 2026, month: 11, day: 12))
}
