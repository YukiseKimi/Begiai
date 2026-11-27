import BegiaiKit
import SwiftUI

struct LineRow: View {
    /// The line's index in the timetable, which picks its colour.
    let line: Int
    let name: String
    let trainsNow: Int
    let starred: Bool
    @Environment(\.linePalette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(palette.color(forLine: line))
                .frame(width: 5, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .font(.body.weight(.medium))
                Text(.lineTrainsNow(count: trainsNow))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(A11yID.Map.lineName)
            Spacer()
            StarButton(kind: .line, name: name, starred: starred)
                .accessibilityIdentifier(A11yID.Map.lineStar)
        }
    }
}

#Preview {
    LineRow(line: 0, name: "Vilnius – Kaunas", trainsNow: 4, starred: true)
        .padding()
}
